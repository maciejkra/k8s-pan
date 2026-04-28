# Solution — 03_own_chart

## Odpowiedzi

### `_helpers.tpl`

Go template snippets reużywane w innych template. Przykład ze scaffolda:

```yaml
{{/*
Fullname: "<release>-<chart>"
*/}}
{{- define "python-api.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}
```

Użycie w innych plikach:
```yaml
metadata:
  name: {{ include "python-api.fullname" . }}
```

Zalety:
- **DRY**: jedno miejsce definicji nazwy (label, service, deployment).
- **Łatwe override przez values** — user może zmienić `fullnameOverride`.

Typowo: `fullname`, `name`, `chart` (nazwa+wersja), `labels` (set wspólnych labelów), `selectorLabels`.

### `version` vs `appVersion`

- **`version`** — wersja chartu (packaging). `0.1.0`, `1.2.3`. Semver obowiązkowe.
- **`appVersion`** — wersja aplikacji inside. `1.0.0`, `"17.2"`. Może być string (nie-semver).

Scenariusz:
- Twoja app na `v1.0.0` — chart na `0.1.0`.
- Poprawiasz Dockerfile aplikacji → `appVersion: 1.0.1`, `version: 0.1.1`.
- Refaktorujesz chart (dodajesz HPA, ingress) **bez** zmian app → `version: 0.2.0`, `appVersion: 1.0.1`.

Oba bump'owane przez Helm Diff CI (renovate). `helm upgrade --version 0.2.0 --set image.tag=v1.0.1`.

### Subcharts (dependencies)

W `Chart.yaml`:
```yaml
dependencies:
  - name: redis
    version: "19.1.0"
    repository: "oci://registry-1.docker.io/bitnamicharts"
    condition: redis.enabled    # install Redis tylko gdy values.redis.enabled=true
```

Następnie:
```bash
helm dependency update ./python-api
# Pobiera Redis tgz do charts/
```

Values parent mogą override subchart:
```yaml
# values.yaml
redis:
  enabled: true
  auth:
    enabled: false     # dla demo, NIE w prod
  master:
    persistence:
      size: 1Gi
```

Use case: mikro-usługa z własną cache — chart aplikacji deploy'uje też Redis. Alternatywa: Redis jako osobny release (lepiej separation of concerns, ale więcej Helm commands).

### Debug templates

```bash
# 1. Lint
helm lint ./python-api
# Warnings: brakujący icon, recommended fields

# 2. Render client-side (bez apiserver)
helm template api ./python-api --debug > /tmp/render.yaml
# Go template errors tu

# 3. Render server-side (z apiserver validation)
helm install api ./python-api --dry-run --debug
# K8s schema errors + admission webhooks (OPA, PSA)

# 4. Manual install + debug
helm install api ./python-api --atomic
# Watch:
kubectl get events -w -n <ns>

# 5. Po zainstalowaniu — różnica vs values
helm get manifest api -n <ns>
helm get values api -n <ns>
```

### Helm hooks vs init containers

**Helm hooks** (`helm.sh/hook: pre-install`):
- Level: **release** — uruchamiane raz przed/po hooks release.
- Wzorce: DB schema migration (raz przed deploy app), external dep setup (cert-manager CRDs).
- Lifecycle: hook Job żyje krótko (sekundy-minuty), kończy sukcesem, Helm kontynuuje.

**Init container** (spec Poda):
- Level: **Pod** — uruchamiany przed każdym startem Pod-a (restart, scale-up).
- Wzorce: fetch config z Vault, wait for dependency, chmod volume.
- Lifecycle: kończy sukcesem przy każdym starcie Pod-a.

Rule of thumb:
- "Run once per deployment" → helm hook.
- "Run every time Pod starts" → init container.

Classic confusion: DB migration
- Hook `pre-upgrade` — tylko raz przy upgrade chartu, nawet jeśli 10 replik.
- Init container — uruchamiałby migration przy każdym restart Pod-a (problem dla concurrent replicas).

## Walidacja

```bash
helm create python-api
# Edytuj Chart.yaml + values.yaml

helm lint python-api/
# 0 failures

helm template test python-api/ | head -20
# K8s YAML output

helm install api python-api/ -n api --create-namespace --atomic
kubectl wait --for=condition=ready pod -n api --all --timeout=60s

helm test api -n api
# Phase: Succeeded

helm upgrade api python-api/ -n api --set replicaCount=5
kubectl get pods -n api | wc -l
# 6 (5 + header)

helm rollback api 1 -n api
kubectl get pods -n api | wc -l
# 3 (2 + header)

helm uninstall api -n api
```

## Troubleshooting

### `Error: template: ... executing "..." at ...: nil pointer`

Brakujący values key. Helm nie zakłada istnienia pól — musisz albo set default, albo zaplug'ować:
```yaml
{{- with .Values.image }}
image: {{ .repository }}:{{ .tag | default "latest" }}
{{- end }}
```

### `helm install` działa, `kubectl get` nic nie widzi

Release w innym NS. `helm list -A` pokazuje wszystkie.

### Subchart values nie override'ują

Prefix musi być **nazwa chartu** (z `dependencies[].name`), nie alias:
```yaml
# Chart.yaml
dependencies:
  - name: redis
    alias: cache            # override — ale values używają aliasu!
# values.yaml
cache:
  enabled: true
  auth: { enabled: false }
```

### HTTPRoute w innym NS niż Gateway — `status` puste, brak routingu

Gateway API: `parentRefs` w HTTPRoute domyślnie celuje w **TEN SAM namespace**. Jeśli chart instaluje aplikację (i jej HTTPRoute) w `python-api`, a `training-gateway` żyje w `default`, HTTPRoute szuka Gateway w `python-api` — nie znajduje, attach silently fails.

Symptom:
```bash
kubectl get httproute -n python-api -o yaml | grep -A2 status:
# status:
#   parents: []          # albo brak status w ogóle
```
+ `curl -H "Host: ..." http://<gateway>/...` zwraca **HTTP 000** lub 404.

Fix: explicit `namespace` w `parentRefs`:
```yaml
spec:
  parentRefs:
    - name: training-gateway
      namespace: default        # ← bez tego HTTPRoute nie attachuje się
  hostnames: [python.127-0-0-1.nip.io]
  rules: [...]
```

Dodatkowo Gateway musi pozwalać na cross-NS routes — `listeners[].allowedRoutes.namespaces.from: All` (lub explicit selector + `ReferenceGrant` w gateway-NS dla bardziej restrictive setup).

Po fix:
```bash
kubectl get httproute -n python-api demo-uri -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}'
# True
```

### `helm test` Pod Running forever

Test Pod nie ma `restartPolicy: Never`. `helm create` scaffold ma OK, ale sprawdź:
```yaml
# templates/tests/test-connection.yaml
spec:
  restartPolicy: Never
  containers:
    - { name: test, image: busybox, command: [...] }
```

## Cross-link

- D5/01/01 (install chart) — CLI basics (helm install, upgrade, rollback)
- D5/01/02 (happy_panda) — OCI chart install — pełne workflow
- D5/02 (kube-prometheus-stack) — consume chart with custom values file
- D4/04 (Vault) — custom values.yaml file pattern
