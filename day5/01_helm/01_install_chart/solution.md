# Solution — 01_install_chart

## Odpowiedzi

### Gdzie helm trzyma stan release

W **Secret** w tym samym namespace co release: `sh.helm.release.v1.<release-name>.v<revision>`. Każda rewizja = osobny Secret (stąd `helm history` może pokazać poprzednie).

Alternatywa: `helm3` obsługuje też ConfigMap (`--history-max 10` limituje historię):
```bash
helm env
# HELM_DRIVER: secret   (lub configmap, sql)
```

Dostęp do Secret:
```bash
kubectl get secret -n <ns> -l owner=helm
kubectl get secret sh.helm.release.v1.<name>.v1 -n <ns> -o jsonpath='{.data.release}' | base64 -d | gunzip | jq
```

### `helm upgrade` vs `kubectl apply`

`kubectl apply` na wyrenderowanym manifeście:
- Nie zna wersji chartu (nie możesz `helm rollback`).
- Nie wie które zasoby są "nasze" vs istniejące — delete z manifestu = nie usunie z klastra.
- Żadna atomicity — częściowo zaaplikowany manifest zostaje.

`helm upgrade --atomic`:
- 3-way merge (last-applied vs current vs new) jak `kubectl apply` ALE śledzi własność przez release secret.
- Delete zasobu z chartu = helm usuwa z klastra.
- `--atomic` = rollback jeśli którykolwiek zasób fail.

### `--atomic` w CI/CD

Bez `--atomic`:
1. `helm upgrade` — 80% zasobów zaaplikowane.
2. Failed: Deployment template validation error.
3. Release status `failed`, klaster w stanie pomieszanym.
4. Następny `helm upgrade` może zwrócić "release has no deployed revision" — awaryjny fix przez `helm history` + manual rollback.

Z `--atomic`:
1. `helm upgrade --atomic` — failed.
2. Helm **auto-rollback** do poprzedniej rewizji.
3. Klaster w znanym dobrym stanie, CI pipeline przerwane z clear error.

Zawsze dodaj w CI: `helm upgrade --install --atomic --timeout 5m --cleanup-on-fail`.

### Debug templates

1. **`helm template --debug`** — render lokalny, widzisz wynik bez apply:
   ```bash
   helm template hello ./mychart --debug > rendered.yaml
   # błędy Go template (np. "expected end")
   ```
2. **`helm install --dry-run --debug`** — server-side validation (K8s schema check):
   ```bash
   helm install hello ./mychart --dry-run --debug
   # błędy schema (np. "port is not a valid int")
   ```
3. **`helm lint`** — statyczny check struktury chartu:
   ```bash
   helm lint ./mychart
   # warnings o brakujących metadata, zalecane pola
   ```

Workflow: lint → template --debug → install --dry-run → faktyczny install.

### Helm hooks

Annotation na zasobie:
```yaml
metadata:
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade
    "helm.sh/hook-weight": "1"
    "helm.sh/hook-delete-policy": before-hook-creation
```

Use cases:
- **`pre-install`/`pre-upgrade`** — DB migration Job (run before new Pods).
- **`post-install`** — smoke test Job, aplikuje demo data.
- **`post-delete`** — cleanup external resources (np. Terraform remote state).
- **`test`** — `helm test` Pod-y (healthcheck po install).

**`hook-delete-policy`**:
- `before-hook-creation` (default) — usuń starego hooka przed nowym
- `hook-succeeded` — usuń po success
- `hook-failed` — usuń po fail (zostaw na debug)

## Walidacja

```bash
helm upgrade --install --atomic hello workshop/hello-world -n workshop --create-namespace
sleep 5
helm ls -n workshop
# STATUS: deployed, REVISION: 1

# Upgrade
helm upgrade --install --atomic hello workshop/hello-world \
  -n workshop --set replicaCount=3
helm history hello -n workshop
# REVISIONS: 1 (superseded), 2 (deployed)

# Rollback
helm rollback hello 1 -n workshop
helm history hello -n workshop
# REVISIONS: 1, 2, 3 (rolled back to 1)

# Cleanup
helm uninstall hello -n workshop
```

## Troubleshooting

### `Error: UPGRADE FAILED: another operation (install/upgrade/rollback) is in progress`

Poprzedni `helm upgrade` został przerwany (Ctrl+C), zostało "pending upgrade" lock. Fix:
```bash
helm rollback hello 0 -n workshop   # 0 = poprzednia stabilna rewizja
# Albo
kubectl delete secret sh.helm.release.v1.hello.v<pending> -n workshop
```

### `--atomic` cofa na "revision 0" przy pierwszym install

`--atomic` przy install (nie upgrade) = delete wszystkiego. To jest zamierzone ("clean state"), ale dla nowego release wydaje się surowe. Rozważ `--cleanup-on-fail` jako mniej agresywne.

### Release "failed" status, nie można upgrade

```bash
helm status hello -n workshop
# STATUS: failed

# Force re-install:
helm uninstall hello -n workshop --keep-history
helm install hello workshop/hello-world -n workshop
```

## Cross-link

- D5/01/02 (happy_panda) — OCI registry install (modern approach)
- D5/01/03 (own_chart) — tworzenie własnego chartu
- D4/04 (Vault) — helm chart instalowany z custom values (vault-values.yaml)
- D5/02 (kube-prometheus-stack) — classic Helm install z -f values.yaml
