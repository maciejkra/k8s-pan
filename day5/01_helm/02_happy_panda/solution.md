# Solution — 02_happy_panda

## Odpowiedzi

### OCI vs klasyczne Helm repo

**OCI (`oci://...`)**:
- Chart jako OCI artifact w Docker/container registry (Docker Hub, GHCR, ECR, Harbor).
- Ten sam registry co obrazy — jedno miejsce auth, monitoring, scanning.
- **Cosign signature support** — `cosign sign oci://.../chart` + `cosign verify`.
- Content-addressable (immutable per digest).

**Helm repo (`helm repo add ...`)**:
- Static HTTP server z `index.yaml` + tar.gz files.
- Starsza konwencja (pre-2022).
- Trudniejsze: own registry wymaga `ChartMuseum` / `Harbor chartmuseum API`.

W 2026: OCI dominuje. `helm repo add` nadal działa dla kompatybilności.

### Bitnami vs oficjalne charty

**Bitnami** (VMware/Broadcom):
- Bogaty ekosystem (WordPress, Redis, MariaDB, Kafka).
- Enterprise-grade values (HA, probes, resources ustawione).
- **Od sierpnia 2025**: obrazy wymagają subskrypcji "Bitnami Secure Images" dla niektórych tagów. Legacy images (stable, pre-2025) nadal free.

**Oficjalne charty** (projekt-specific):
- Prometheus Operator (jak my używamy), cert-manager, Istio.
- Często bardziej opinionated (less flexible, but best-practice baked in).
- Zwykle aktualizowane wraz z main projektem.

**Community** (`artifacthub.io`):
- Mixed quality — od enterprise (Grafana Labs) do hobby.
- Zawsze sprawdź: `helm show chart oci://... | head -20` (metadata, maintainer, home URL).

### Verify chart signature

**Cosign** (Sigstore):
```bash
cosign verify oci://registry-1.docker.io/bitnamicharts/wordpress:17.1.0 \
  --certificate-identity="*" \
  --certificate-oidc-issuer="*"

# Output: verification success
```

Keyless signing (OIDC) — certyfikat w transparency log (Rekor). Jeśli chart sign'owany przez VMware GitHub Actions → verify zwróci metadata workflow.

Bez cosign: `helm pull` + compare SHA256 z expected:
```bash
helm pull oci://.../wordpress --version 17.1.0
sha256sum wordpress-17.1.0.tgz
```

### Pin wersji

Zawsze:
```bash
helm install ... oci://.../wordpress --version 17.1.0
```

Nie:
```bash
helm install ... oci://.../wordpress       # implicit latest
```

Powody:
- Reproducibility CI.
- Rollback nie ma gdzie rollbackować jeśli latest jest moving target.
- Auditability ("które chart deploy'owany w grudniu?").

Automation: **Renovate bot** / **Dependabot** PR-y z nową wersją chartu → CI testuje → merge.

### Subchart mariadb auth

Values.yaml parent chart może override subchart przez prefix:
```yaml
# values-override.yaml
mariadb:                        # nazwa subchartu z Chart.yaml
  auth:
    rootPassword: "x"
  primary:
    resources:
      requests: { memory: 256Mi }
```

Dla secrets (best practice) — **global Secret** referenced przez oba:
```yaml
mariadb:
  auth:
    existingSecret: "db-credentials"   # pre-exist Secret
```

## Walidacja

```bash
helm install my-wp oci://registry-1.docker.io/bitnamicharts/wordpress \
  -n wordpress --create-namespace -f values-override.yaml

kubectl wait --for=condition=ready pod -n wordpress --all --timeout=5m

helm list -n wordpress
# NAME   NAMESPACE  REVISION  CHART        STATUS
# my-wp  wordpress  1         wordpress-*  deployed

# Port-forward, WordPress UI dostępny
kubectl port-forward -n wordpress svc/my-wp 8080:80 &
curl -sI http://localhost:8080 | head -3
# HTTP/1.1 200 OK
```

## Troubleshooting

### `failed to fetch: HEAD ... unauthorized`

Docker Hub rate limit (anonymous). Login:
```bash
docker login
helm registry login -u $USERNAME registry-1.docker.io
```

### MariaDB pod CrashLoopBackOff

```bash
kubectl logs -n wordpress my-wp-mariadb-0
# Typowe: PV permission denied (local-path SC z K3s)
```
Fix: `--set mariadb.primary.podSecurityContext.fsGroup=1001`.

### WordPress "connection refused" przy setup

Dodaj wait: WordPress Pod startuje szybciej niż MariaDB przyjmie połączenia.
```bash
kubectl wait --for=condition=ready pod -n wordpress -l app.kubernetes.io/name=mariadb --timeout=3m
kubectl rollout restart -n wordpress deployment/my-wp
```

## Cross-link

- D5/01/01 (install chart) — Helm CLI basics
- D5/01/03 (own chart) — jak build własny chart
- D4/04 (Vault) — Helm chart install z values file (vault-values.yaml)
- D5/02 (kube-prometheus-stack) — ten sam wzorzec: OCI chart + helm upgrade -f values.yaml
