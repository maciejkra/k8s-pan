# Solution — 04_vault

## Odpowiedzi

### 3 wzorce — kiedy który

| Wzorzec | Kiedy użyć | Przykład |
|---|---|---|
| **CSI volume** | Aplikacja czyta secret z pliku (TLS cert, SSH key) — rotacja auto-refreshuje plik | nginx z TLS (`/certs/server.crt`) |
| **CSI + sync Secret → env** | Legacy aplikacja nie wie o Vault, tylko `os.environ['DB_PASS']` | Spring Boot z `${DB_PASS}` |
| **Agent Injector** | Multi-env templating (format config który nie jest plain password) | `database-config.txt` z `{ host, port, user, password }` rendered z template |

Konsekwencja: Injector jest **najbardziej elastyczny** (Go templates), ale dodaje 2 kontenery (init + sidecar). CSI prostsze, ale ogranicza formatowanie.

### CSI vs Injector — rotacja

- **CSI**: syncuje secret co `--rotation-poll-interval` (default 2 min). Plik w `/mnt/secrets-store` się zmienia. Aplikacja musi watchować plik (inotify) albo okresowo re-czytać. **Bez restartu Pod-a**.
- **Injector (classic)**: sidecar `vault-agent` periodycznie renew'uje lease (dla dynamic secrets) i re-renderuje plik. Static secrets (`secret/data/...`) z `ttl=20m` — agent odświeża co 20m. **Bez restartu Pod-a**.
- **Sync-to-K8s-Secret przez envFrom**: env var w procesie **nigdy** się nie zmienia bez restartu. Musi być `volumeMount` + plik albo restart Poda.

Praktyka: CSI volume = rotacja bez restartu (dla file-based). Env = rotacja wymaga restartu.

### `bound_service_account_namespaces`

Scope do namespace (nie tylko po SA name) bo **SA names są per-namespace**. `app-sa` w `default` i `app-sa` w `other-ns` to różne podmioty. Bez scope NS, policy `bound_service_account_names=app-sa` byłaby multi-tenant leak: każdy NS z SA `app-sa` dostałby dostęp.

Dodatkowo: `bound_service_account_namespaces=*` pozwala wszystkim NS — używać tylko jeśli świadomie wiesz że wszystkie NS w klastrze są zaufane.

### K8s 1.24+ legacy SA tokens

Przed K8s 1.24: każdy SA dostawał auto-utworzony Secret `kubernetes.io/service-account-token` z długo-żyjącym JWT.

Od K8s 1.24: **projected tokens** (krótko-żyjące, 60min TTL, auto-rotate). Vault k8s auth domyślnie używa `tokenReviewer` z **long-lived** tokena.

**Problem**: Vault config z `kubernetes_host` i **pustym** `token_reviewer_jwt` → Vault używa własnego SA tokena (projected, krótko żyjącego). Na K8s 1.24+ to działa (K8s akceptuje projected tokens w TokenReview), ale **wymaga Vault 1.11+** z wsparciem projected tokens.

Obejścia:
1. Ręcznie utwórz Secret `type: kubernetes.io/service-account-token` z annotacją `kubernetes.io/service-account.name=vault` → K8s auto-wypełni token (legacy, ale działa).
2. Bump Vault do ≥1.11 (w 2026 stabilne 1.17+). Chart 0.30 używa 1.17.

### Rollout SA credentials w Vault (sketch)

1. **Rotate root token**: `vault operator rotate-root` (Vault 1.14+). Stare root token dalej działa do `vault token revoke <old-root>`.
2. **Rotate unseal keys**: `vault operator rekey -init -key-shares=5 -key-threshold=3` → GeneratePASSphrase dla nowych share'ów → distribute do kluczy. Stare unseal keys revoked.
3. **Rotate secret/* engine key** (transit, kv): dla kv — rewrite secret z nową wartością (versioning). Dla transit — `vault write -f transit/keys/my-key/rotate`.

## Walidacja

```bash
# Vault działa
kubectl -n vault get pods
# vault-0      1/1   Running
# vault-agent-injector-xxx 1/1 Running

# Secret poprzez wszystkie 3 wzorce
kubectl exec webapp -- cat /mnt/secrets-store/db-password
kubectl exec webapp-env -- sh -c 'echo $DB_PASSWORD'
kubectl exec webapp-inject -c webapp -- cat /vault/secrets/database-config.txt
# Wszystkie zwracają: supersecret-change-me
```

## Troubleshooting

### Vault pod w `CrashLoopBackOff`

```bash
kubectl logs -n vault vault-0 --previous
```
Typowe:
- `dev.enabled: true` + `dataStorage.enabled: true` = konflikt. Fix: ustaw `dataStorage.enabled: false`.
- Port 8200 conflict (inny proces słucha lokalnie). Fix: `kubectl port-forward` używa świeżego portu.

### `permission denied: no permission on path "secret/data/db-pass"`

Policy lub role nie matchuje SA. Debug:
```bash
kubectl exec -it -n vault vault-0 -- sh
vault read auth/kubernetes/role/database
# Sprawdź bound_service_account_names i namespaces

vault policy read internal-app
# Sprawdź path == "secret/data/db-pass" (uwaga na "secret/db-pass" vs "secret/data/db-pass" — KV v2 ma prefix "data/")
```

### CSI Pod w `ContainerCreating` forever

```bash
kubectl describe pod webapp
# Events: "failed to provision volume with StorageClass..."
```
Typowo: CSI driver nie zainstalowany albo SecretProviderClass w innym NS niż Pod.

### Injector nie wstrzyknął sidecar

```bash
kubectl get mutatingwebhookconfiguration vault-agent-injector-cfg -o yaml
# Sprawdź czy webhook target (namespaceSelector) matchuje namespace Pod-a

kubectl logs -n vault deploy/vault-agent-injector
# Sprawdź czy webhook dostał request dla tego Poda
```

## Cross-link

- D2/10 (K8s Secrets) — Vault to step-up od base64 secretów
- D4/05 (SecurityContext) — Injector Pody mogą mieć problem z `enforce: restricted` PSA (D4/02)
- D4/02 (PSA) — Vault w dev mode NIE spełnia restricted (privileged capability); dla prod harden values.yaml
- D5/02 (Monitoring) — Vault telemetry przez Prometheus (`telemetry { prometheus_retention_time = "24h" }`)
