# 03 — Helm: tworzenie własnego chartu

## Cel
Wygenerować scaffold własnego chartu (`helm create`), zrozumieć strukturę, zmodyfikować templates i values.

## Kontekst
Helm chart = paczka K8s manifestów + szablony Go templates + values do parametryzacji.

Struktura:
```
mychart/
├── Chart.yaml          # metadata (name, version, dependencies)
├── values.yaml         # default values (overridable)
├── charts/             # subcharts (dependencies)
└── templates/          # Go templates używające .Values
    ├── deployment.yaml
    ├── service.yaml
    ├── ingress.yaml
    └── _helpers.tpl    # reusable template snippets
```

## Prereqs
- K3d/Kind cluster
- helm

## Zadanie

1. Wygeneruj scaffold:
   ```bash
   helm create python-api
   ```

2. Sprawdź strukturę:
   ```bash
   tree python-api/
   ```

3. Edytuj `python-api/Chart.yaml` (metadata):
   ```yaml
   apiVersion: v2
   name: python-api
   version: 0.1.0
   appVersion: "1.0"
   description: Demo Python API
   ```

4. Edytuj `python-api/values.yaml` — defaultowe values:
   ```yaml
   replicaCount: 2
   image:
     repository: python-api
     tag: latest
   service:
     type: ClusterIP
     port: 8080
   ```

5. Render template lokalnie (debug, bez install):
   ```bash
   helm template python-api/ --set replicaCount=5
   ```

6. Lint (sprawdź poprawność):
   ```bash
   helm lint python-api/
   ```

7. Install:
   ```bash
   helm install api ./python-api
   helm list
   ```

8. Upgrade z innym values:
   ```bash
   helm upgrade api ./python-api --set replicaCount=10
   helm history api
   ```

9. Rollback:
   ```bash
   helm rollback api 1
   ```

## Pytania kontrolne
1. `_helpers.tpl` — co tam się trzyma i dlaczego?
2. `Chart.yaml` `version` vs `appVersion` — różnica?
3. Subcharts (`dependencies`) — kiedy używać?
4. Jak debugować templates gdy `helm install` failuje? (Hint: `--dry-run --debug`)

## Linki
- [Helm Charts](https://helm.sh/docs/topics/charts/)
- [Debugging templates](https://helm.sh/docs/chart_template_guide/debugging/)
- [Best practices for chart authors](https://helm.sh/docs/chart_best_practices/)
