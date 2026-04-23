# Solution — 10_secrets

## Odpowiedzi

### `stringData` vs `data`

- **`stringData`** — raw wartości. K8s API sam base64-uje przed zapisem. Wygodne w manifestach, git diffach, template'ach Helm. Write-only (kubectl pokazuje wynik w `data.`).
- **`data`** — wartości już base64. Wymagane gdy:
  - Zawartość to **binary** (np. `.p12` keystore, `.pfx` cert) — stringData nie przyjmuje binary.
  - Operator / controller zapisuje Secret przez API (API zwraca base64).
  - Eksportujesz z K8s przez `-o yaml` — dostajesz `data:`.

W 90% ręcznie-pisanych manifestów → `stringData`.

### `immutable: true`

```yaml
immutable: true
```

- **Zablokowane**: `kubectl edit/patch/apply` na wartości. Tylko `delete + recreate`.
- **Nie zablokowane**: `kubectl delete secret` i potem recreate z inną nazwą.
- **Korzyść**: kontroler `kube-controller-manager` nie watchuje immutable Secretów → oszczędność memory/CPU w klastrach z 10k+ Secretów.
- **Kiedy używać**: release-specific secrety (tagowane wersją np. `app-creds-v1.2.3`). Rotujesz przez nowy Secret z nową nazwą + patch Deployment — zero downtime.

### Refresh env vs volume

| | Env vars (`envFrom`) | Volume mount |
|---|---|---|
| Co dostaje Pod | snapshot wartości w momencie startu | symlink do kubelet-sync'owanego pliku |
| Zmiana Secret widoczna | **nigdy** (pod musi być restartowany) | po ~60s (kubelet `syncFrequency`) |
| Aplikacja musi | restart | watch pliku (np. `inotify`) albo re-read |

**Konsekwencja praktyczna**: rotacja haseł przez Secret + env = downtime (restart Pod), rotacja przez volume = seamless jeśli aplikacja wspiera reload (Envoy, nginx SIGHUP).

**Tricks**:
- **Reloader** (stakater/reloader) — operator który patchuje Pod Spec po zmianie Secret/ConfigMap → rolling update.
- **Checksum annotation** w Helm: `annotations: { checksum/secret: {{ include (print .Template.BasePath "/secret.yaml") . | sha256sum }} }` — Deployment template zmienia annotation przy zmianie Secret → rolling update.

### Legacy SA tokens

**Przed K8s 1.24**: każdy ServiceAccount dostawał automatycznie Secret typu `kubernetes.io/service-account-token` z długo-żyjącym JWT tokenem. Problem: tokeny siedziały w etcd na zawsze, wyciek był trwały.

**Od K8s 1.24**: default to **projected SA tokens** — mountowane jako krótko-żyjące JWT (60 min rotation) przez `automountServiceAccountToken: true`. Żaden Secret nie jest auto-tworzony. Jeśli potrzebujesz długo-żyjącego tokena (legacy integrations):

```yaml
apiVersion: v1
kind: Secret
type: kubernetes.io/service-account-token
metadata:
  name: my-sa-token
  annotations:
    kubernetes.io/service-account.name: my-sa
```

Kontroler uzupełni token w `data.token`. Ale pamiętaj: **długo-żyjący token = większe ryzyko**. Preferuj projected.

### Kiedy K8s Secrets nie wystarcza

1. **Dynamic secrets** — DB credential który rotuje co 24h (Vault daje to out-of-box, K8s Secret jest statyczny do ręcznego patcha).
2. **Audit & compliance** (SOC2, PCI-DSS) — "kto i kiedy odczytał secret" — K8s audit log pokazuje tylko `kubectl get`, nie dostęp przez SA z Pod. Vault ma full audit log.
3. **Cross-cluster / multi-cloud secrets** — jeden source of truth dla 10 klastrów. K8s Secret żyje w jednym etcd. ESO sync z AWS SM / GCP SM / Azure KV.
4. **Encryption-at-rest wymagany** bez zaufania do etcd — nawet z `encryption-provider-config`, klucz szyfrujący leży na kube-apiserver node. Vault trzyma klucz w KMS/HSM.
5. **PKI / certyfikaty z TTL** — cert-manager rozwiązuje częściowo, ale Vault PKI engine + intermediate CA = pełny flow.

## Walidacja końcowa

```bash
# 1. Generic Secret
kubectl get secret app-credentials -o jsonpath='{.data.db-user}' | base64 -d
# admin

# 2. Consumer Pod
kubectl logs secret-consumer | grep -E "DB_USER|supersecret"
# DB_USER=admin
# DB_PASSWORD=supersecret-change-me

# 3. Eksperyment refresh
kubectl patch secret app-credentials -p '{"stringData":{"db-password":"new"}}'
sleep 75
kubectl exec secret-consumer -- cat /etc/secret/db-password
# new                       ← volume zrefreshowany

kubectl exec secret-consumer -- sh -c 'echo $DB_PASSWORD'
# supersecret-change-me     ← env NIE zrefreshowany

kubectl delete pod secret-consumer
kubectl wait --for=condition=ready pod/secret-consumer --timeout=30s
kubectl exec secret-consumer -- sh -c 'echo $DB_PASSWORD'
# new                       ← po restart env zaktualizowany
```

## Troubleshooting

### `kubectl exec` pokazuje puste env

Jeśli Secret NIE istnieje w momencie startu Poda, `envFrom` błędnie inicjuje env jako puste. Pod NIE fail'uje! Fix: dodaj `envFrom` z `optional: false` (default) + sprawdzaj `kubectl get events`.

### Volume `mountPath` kolizja

Jeśli montujesz Secret w `/etc/secret` a kontener ma coś w `/etc/secret` natywnie — zostaje nadpisane na czas życia Poda. Użyj `subPath` żeby zamontować pojedynczy klucz:

```yaml
volumeMounts:
  - name: creds
    mountPath: /etc/nginx/ssl/cert.pem
    subPath: cert.pem
```

### Registry Secret — "no basic auth credentials"

```bash
kubectl describe pod <name> | grep -i pull
# Failed to pull image: ... unauthorized: no basic auth credentials
```

Sprawdź:
- `imagePullSecrets` jest w `spec` (nie w `containers`).
- Secret jest w **tym samym namespace** co Pod.
- Secret jest typu `kubernetes.io/dockerconfigjson` (`kubectl get secret X -o yaml | grep type`).

## Cross-link

- D4/04 (Vault) — produkcyjny secret manager, multi-pattern (CSI / injector) + sekcja ESO
- D2/07 (Gateway API) — użycie TLS Secret w listener HTTPS
- D3/08 (NetworkPolicy) — ograniczenie dostępu do Pod-a który ma Secret (defense-in-depth)
- D4/02 (PSA) — Pod Security Admission nie blokuje Secret access (to jest w RBAC, D2/06)
