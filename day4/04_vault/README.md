# 04 — HashiCorp Vault (3 wzorce konsumpcji secretów)

## Cel
Zainstalować Vault w trybie dev, skonfigurować auth Kubernetes + policy + role, i zobaczyć **trzy wzorce** konsumpcji secretów w Podzie:

1. **CSI Secrets Store** → pliki w volume (`/mnt/secrets-store/db-password`)
2. **CSI + sync do K8s Secret** → env var przez `valueFrom.secretKeyRef`
3. **Vault Agent Injector** → sidecar renderuje plik z template (`/vault/secrets/database-config.txt`)

Plus omówienie **External Secrets Operator (ESO)** jako cloud-native alternatywy.

## Kontekst

K8s Secrets (D2/10) = base64 w etcd. W produkcji:
- **Dynamic secrets** (DB credentials rotowane co 24h) — wymagają external manager.
- **Audit logów** ("kto czytał secret X w grudniu") — K8s tylko pokazuje kto miał RBAC, nie kto faktycznie odczytał.
- **Encryption at rest niezależne od etcd** — klucz w KMS/HSM, nie na kube-apiserver node.

Vault adresuje wszystkie trzy + oferuje PKI, transit encryption, SSH CA, Cubbyhole.

### Kiedy Vault vs ESO?

| | Vault | External Secrets Operator (ESO) |
|---|---|---|
| Backend | Vault (self-hosted) | AWS SM / GCP SM / Azure KV / **Vault** / 1Password / … |
| Pod konsumpcja | Sidecar injector / CSI volume / CSI env | `envFrom: secretRef` (ESO syncuje do natywnego K8s Secret) |
| Dynamic secrets | Native (DB, PKI, SSH) | Read-only z backendu; brak dynamic |
| Audit | Bogaty (per-request log) | Brak (tylko AWS CloudTrail etc.) |
| Złożoność | Wysoka (init, unseal, HA) | Niska (operator + CRD) |
| Produkcja 2026 | Enterprise / multi-cloud — klasyka | Cloud-native single-cloud — de-facto standard |

**Decyzja w pigułce**: ESO dla 80% cloud-native use cases, Vault dla PKI/dynamic/multi-DC enterprise.

## Prereqs
- K3s / Kind / K3d cluster
- `helm` CLI

## Pliki

| Plik | Co |
|---|---|
| `vault-values.yaml` | Helm values dla Vault dev mode |
| `csisecret.yaml` | SecretProviderClass `vault-database` (CSI volume) |
| `csisecret-env.yaml` | SecretProviderClass `vault-database-env` (CSI + sync do K8s Secret) |
| `csi-pod.yaml` | Pod konsumujący CSI volume |
| `csi-pod-env.yaml` | Pod konsumujący sync'ed Secret jako env |
| `inject-pod.yaml` | Pod z annotacjami Agent Injector |

## Zadanie

Patrz [`task.md`](./task.md).

## Linki
- [Vault Helm chart](https://github.com/hashicorp/vault-helm)
- [Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/)
- [Vault Agent Injector](https://developer.hashicorp.com/vault/docs/platform/k8s/injector)
- [External Secrets Operator](https://external-secrets.io/)
- [Vault Kubernetes auth](https://developer.hashicorp.com/vault/docs/auth/kubernetes)
