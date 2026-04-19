# 04 — Monitoring i Alerting (Prometheus + Grafana + Loki)

## Cel
Zainstalować pełny stack observability: Prometheus (metryki) + Grafana (dashboards) + Loki (logi) + AlertManager (alerty). Sprawdzić preinstall'd dashboards.

## Kontekst
**kube-prometheus-stack** to standardowy Helm chart łączący:
- **Prometheus Operator** — manage Prometheus instances przez CRD-y (ServiceMonitor, PrometheusRule)
- **Prometheus** — time-series DB + scraping
- **AlertManager** — routing alertów (Slack, PagerDuty, email)
- **Grafana** — wizualizacja, preinstall'd dashboards K8s
- **node-exporter** (DaemonSet) — metryki per-node (CPU, memory, disk)
- **kube-state-metrics** — metryki o obiektach K8s (Pod count, Deployment status)

**Loki** (Grafana Labs) — like Prometheus, but for **logs**. Lekki (LogQL podobny do PromQL), kompatybilny z Grafana.

Razem = "darmowy Datadog" dla K8s.

## Prereqs
- Kind/K3d cluster z odpowiednim resource budget (recommend 4 CPU, 8GB RAM)
- helm

## Zadanie

### Prometheus Operator + Grafana + AlertManager

1. Postaw klaster (jeśli nie z setup-cluster.sh):
   ```bash
   kind create cluster --config ./kind.yaml --name workshop
   ```

2. Helm install kube-prometheus-stack:
   ```bash
   helm upgrade --install --wait --timeout 15m \
     --namespace monitoring --create-namespace \
     --repo https://prometheus-community.github.io/helm-charts \
     kube-prometheus-stack kube-prometheus-stack \
     -f values.yaml
   ```

3. Port-forward Grafana:
   ```bash
   kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
   ```

4. Otwórz `http://localhost:3000` — login: `admin` / `prom-operator`. Sprawdź preinstall'd dashboards (Cluster, Node, Pod, Workload).

5. Sprawdź ServiceMonitor:
   ```bash
   kubectl get servicemonitor -A
   # Lista: jakie services są scrapowane
   ```

### Loki (logs)

1. Install:
   ```bash
   helm upgrade --install loki grafana/loki-stack --namespace=loki --create-namespace
   ```

2. W Grafana: dodaj data source Loki, URL: `http://loki.loki.svc.cluster.local:3100`

3. Logs Explorer w Grafanie — query LogQL:
   ```
   {namespace="default"} |= "error"
   {pod=~"nginx-.*"} |= "GET"
   ```

### Custom alerts

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata: { name: my-alerts, namespace: monitoring }
spec:
  groups:
    - name: app.alerts
      rules:
        - alert: HighErrorRate
          expr: |
            sum(rate(http_requests_total{status=~"5.."}[5m])) > 0.05
          for: 5m
          annotations:
            summary: "Error rate > 5% przez 5 min"
```


## Linki
- [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Loki LogQL](https://grafana.com/docs/loki/latest/logql/)
- [Prometheus Operator CRDs](https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/api.md)

## Cross-link
- D4/07 Trivy Operator → eksportuje metryki o CVE → wizualizacja w Grafanie (dashboard 17813)
- D4/08 Falco → events do Loki (przez Falcosidekick)
- D5/04 GPU → DCGM Exporter dashboard 12239
