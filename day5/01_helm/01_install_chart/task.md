# Zadanie

## Część 1 — Repo & search

```bash
helm repo add workshop https://maciejkra.github.io/helm/
helm repo update
helm search repo workshop
# Lista chartów z workshop repo
```

**Uwaga**: jeśli repo nie odpowiada (404, maintenance) — użyj publicznego `bitnami/wordpress` dla tej samej dydaktyki (patrz `02_happy_panda/`).

## Część 2 — Install warianty

```bash
# Idempotent (CI-friendly)
helm upgrade --install --atomic hello workshop/hello-world \
  -n workshop --create-namespace

# Alternatywy:
# helm install hello workshop/hello-world -n workshop
# helm install --generate-name workshop/hello-world -n workshop
```

## Część 3 — Weryfikacja

```bash
helm ls -n workshop
# NAME   NAMESPACE  REVISION  STATUS    CHART
# hello  workshop   1         deployed  hello-world-0.1.0

kubectl get all -n workshop

# Helm trzyma stan release w Secret:
kubectl get secret -n workshop -l owner=helm
```

## Część 4 — Customize values

```bash
# Inline
helm upgrade --install --atomic hello workshop/hello-world \
  -n workshop --set replicaCount=3

# Z pliku
cat <<EOF > values-custom.yaml
replicaCount: 5
image:
  tag: v2.0
EOF

helm upgrade --install --atomic hello workshop/hello-world \
  -n workshop -f values-custom.yaml
```

## Część 5 — History i rollback

```bash
helm history hello -n workshop
# REVISION  UPDATED  STATUS     DESCRIPTION
# 1         ...      superseded Install complete
# 2         ...      deployed   Upgrade complete

helm rollback hello 1 -n workshop
helm history hello -n workshop
# REVISION 3 deployed (rolled back from 2 to 1)
```

## Część 6 — Debug

```bash
# Render templates lokalnie (bez apply)
helm template hello workshop/hello-world --debug

# Dry-run (server-side validation)
helm install hello workshop/hello-world --dry-run --debug -n workshop
```

## Część 7 — Cleanup

```bash
helm uninstall hello -n workshop
kubectl delete namespace workshop
```

## Pytania

1. Gdzie helm trzyma stan release? (Hint: Secret `sh.helm.release.v1.<release>.v<revision>` w namespace.)
2. `helm upgrade` vs `kubectl apply` na wygenerowanym manifeście — dlaczego helm lepszy dla complex charts?
3. `--atomic` — czemu krytyczne w CI/CD? (Hint: rollback przy fail.)
4. Jak debugować błędy template'u przed install? (Hint: `helm template --debug`.)
5. **Bonus**: Helm hook (`pre-install`, `post-upgrade`) — kiedy używać? (Hint: DB migrations, cleanup.)
