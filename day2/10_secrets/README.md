# 10 — Secrets (generic, docker-registry, tls)

## Cel
Stworzyć Secrets różnych typów i bezpiecznie je konsumować w Pod (env vars + mounted files). Zrozumieć dlaczego K8s Secrets to NIE jest pełne rozwiązanie security i kiedy iść w stronę Vault (D4/04) / ESO / SOPS / Sealed Secrets.

## Kontekst
**Secret** = analogiczne do ConfigMap, ale dla danych wrażliwych. **Domyślnie NIE jest szyfrowany** w etcd (tylko base64 encoded — nie myl z encryption!). W produkcji potrzebujesz **encryption-at-rest** dla etcd + RBAC + zewnętrzny secret manager.

### Typy Secret

- `Opaque` (`generic`) — dowolne klucz-wartość (default)
- `kubernetes.io/dockerconfigjson` (`docker-registry`) — credentials do prywatnego rejestru obrazów
- `kubernetes.io/tls` (`tls`) — cert + klucz prywatny dla TLS (Ingress, Gateway API)
- `kubernetes.io/service-account-token` — auto-generowane dla SA (legacy, patrz niżej)
- `kubernetes.io/basic-auth`, `kubernetes.io/ssh-auth`

### `data` vs `stringData`

- `data.klucz: <base64>` — wartość już zbase64-owana. API ją dekoduje do storage.
- `stringData.klucz: raw` — raw wartość, K8s sam base64-uje. **Dużo wygodniejsze** w manifestach. Sygnatura zmiany: `kubectl get secret ... -o yaml` pokazuje wynik w `data.`, `stringData.` jest write-only.

### Immutable Secrets (K8s 1.21+)

```yaml
immutable: true
```

Secret nie da się modyfikować (tylko delete + recreate). **Korzyść wydajnościowa**: kube-controller-manager nie watchuje immutable Secrets → mniej obciążenia API servera w klastrach z tysiącami Secretów. Praktyka: secrety release-specific (tag-pinned) rób immutable.

### Base64 to NIE encryption

```bash
echo 'supersecret' | base64    # c3VwZXJzZWNyZXQK
echo 'c3VwZXJzZWNyZXQK' | base64 -d  # supersecret
```

Każdy kto ma `kubectl get secret` lub dostęp do etcd widzi wartości w czystym tekście po `base64 -d`. Secrets chroni tylko **RBAC** (komu pozwolisz robić `get secret`). Produkcyjnie:
- **etcd encryption-at-rest** — `kube-apiserver --encryption-provider-config=...` (key rotation!)
- **External secret manager** — Vault (D4/04), AWS Secrets Manager (przez ESO — zobacz D4/04), 1Password Connect
- **SOPS** — encrypted YAML w Git, decrypt przy `kubectl apply` (helm-secrets plugin)
- **Sealed Secrets** — encrypted manifesty w Git, decrypt przez controller w klastrze

### Legacy ServiceAccount tokens

K8s 1.24+ nie tworzy automatycznie Secret typu `kubernetes.io/service-account-token` dla SA. Zamiast tego: **projected tokens** (short-lived, auto-rotated) montowane przez `automountServiceAccountToken: true`. Dla klientów wymagających długo-żyjącego tokena (legacy CI, Vault kubernetes auth na starszych setupach) — tworzysz Secret ręcznie:

```yaml
apiVersion: v1
kind: Secret
type: kubernetes.io/service-account-token
metadata:
  name: my-sa-token
  annotations:
    kubernetes.io/service-account.name: my-sa
```

## Prereqs
- K3s / Kind / K3d cluster

## Pliki w katalogu

| Plik | Co pokazuje |
|---|---|
| `secret-generic.yaml` | Opaque Secret z `stringData` (wygodny format) + komentarz o `immutable` |
| `consumer-pod.yaml` | Pod konsumujący ten sam Secret **jednocześnie** przez env + volume mount |

Dla `docker-registry` i `tls` używamy komend `kubectl create secret` (są trudne do ręcznego skonstruowania w YAML z powodu base64 dockerconfigjson / cert PEM).

## Zadanie

Patrz [`task.md`](./task.md).

## Linki
- [Secret docs](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Encrypting data at rest](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/)
- [Distribute credentials securely](https://kubernetes.io/docs/tasks/inject-data-application/distribute-credentials-secure/)
- [Pull image from private registry](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/)

## Alternatywy / dobre praktyki produkcyjne

- [**HashiCorp Vault**](https://www.vaultproject.io) — patrz **D4/04** (multi-pattern: CSI Driver / injector)
- [**External Secrets Operator (ESO)**](https://external-secrets.io/) — sync z AWS Secrets Manager / GCP Secret Manager / Azure Key Vault / Vault / 1Password do natywnych K8s Secret. Patrz D4/04 "Alternatywa: ESO"
- [`getsops/sops`](https://github.com/getsops/sops) — szyfrowane YAML w Git, decrypt przy `kubectl apply`
- [`bitnami-labs/sealed-secrets`](https://github.com/bitnami-labs/sealed-secrets) — encrypted Secrets w Git, decrypt przez controller w klastrze
