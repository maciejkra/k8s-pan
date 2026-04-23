# Zadanie

## Część 1 — Wygeneruj scaffold

```bash
helm create python-api
tree python-api/
# python-api/
# ├── Chart.yaml
# ├── values.yaml
# ├── charts/
# ├── templates/
# │   ├── deployment.yaml
# │   ├── service.yaml
# │   ├── ingress.yaml
# │   ├── hpa.yaml
# │   ├── serviceaccount.yaml
# │   ├── _helpers.tpl
# │   ├── NOTES.txt
# │   └── tests/
# │       └── test-connection.yaml
# └── .helmignore
```

## Część 2 — Edytuj Chart.yaml

```bash
cat > python-api/Chart.yaml <<EOF
apiVersion: v2
name: python-api
description: Python REST API with Redis backend (D1/10)
type: application
version: 0.1.0
appVersion: "1.0.0"
home: https://github.com/maciejkra/k8s-training-2026
maintainers:
  - name: Maciej Krajewski
    email: maciejkra@gmail.com
EOF
```

## Część 3 — Edytuj values.yaml (kluczowe zmiany)

Otwórz `python-api/values.yaml` i zmień:

```yaml
replicaCount: 2

image:
  repository: krajewskim/python-api   # z D1/10
  pullPolicy: IfNotPresent
  tag: "new"                          # pin wersji, nie latest

service:
  type: ClusterIP
  port: 5002

ingress:
  enabled: false                       # dla D2/07 Gateway API używamy HTTPRoute

resources:
  requests: { cpu: 100m, memory: 128Mi }
  limits: { memory: 256Mi }

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 50
```

## Część 4 — Lint + render

```bash
# Statyczny check
helm lint python-api/
# ==> Linting python-api/
# [INFO] Chart.yaml: icon is recommended
# 1 chart(s) linted, 0 chart(s) failed

# Render bez apply
helm template my-api python-api/
# Pełny YAML render

# Z override
helm template my-api python-api/ --set replicaCount=5
```

## Część 5 — Install

```bash
helm install api python-api/ -n api --create-namespace
helm list -n api
kubectl get all -n api
```

## Część 6 — Upgrade + rollback

```bash
helm upgrade api python-api/ -n api --set replicaCount=5
helm history api -n api
helm rollback api 1 -n api
```

## Część 7 — Helm test (smoke check)

```bash
# helm create scaffoldował test Pod w templates/tests/
helm test api -n api
# Pod `api-test-connection` uruchomi wget na Service
# Pass → release zdrowe
```

## Część 8 — Bonus: NOTES.txt customization

Edytuj `python-api/templates/NOTES.txt`:
```
{{ .Release.Name }} zainstalowany w namespace {{ .Release.Namespace }}.

Aby sprawdzić aplikację:
  kubectl port-forward -n {{ .Release.Namespace }} svc/{{ include "python-api.fullname" . }} 5002
  curl http://localhost:5002/api/v1/info
```

Po `helm install` te NOTES pokazują się w terminalu — idealne dla onboardingu nowych użytkowników chartu.

## Część 9 — Cleanup

```bash
helm uninstall api -n api
kubectl delete namespace api
```

## Pytania

1. `_helpers.tpl` — co tam się trzyma i dlaczego? (Hint: reusable Go template snippets, np. `{{ include "fullname" . }}`.)
2. `Chart.yaml` `version` vs `appVersion` — różnica? (Chart version = paczka, App version = software inside.)
3. Subcharts (`dependencies`) — kiedy używać? (Hint: twoja aplikacja zależy od Redis — pin w Chart.yaml, helm pobiera przy install.)
4. Jak debugować templates gdy `helm install` failuje? (`--dry-run --debug`, `helm template`, `helm lint`.)
5. **Bonus**: Helm hooks vs init containers — kiedy każde?
