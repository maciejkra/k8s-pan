# 02 — Monitoring i Alerting (Prometheus + Grafana + Loki)

## Cel
Zainstalować pełny stack observability: Prometheus (metryki) + Grafana (dashboards) + Loki (logi) + AlertManager (alerty). Sprawdzić preinstall'd dashboards. Dopisać własny alert (PrometheusRule) i ServiceMonitor dla custom app.

## Kontekst
**kube-prometheus-stack** to standardowy Helm chart łączący:
- **Prometheus Operator** — manage Prometheus instances przez CRD-y (ServiceMonitor, PodMonitor, PrometheusRule, AlertmanagerConfig)
- **Prometheus** — time-series DB + scraping
- **AlertManager** — routing alertów (Slack, PagerDuty, email)
- **Grafana** — wizualizacja, preinstall'd dashboards K8s
- **node-exporter** (DaemonSet, D2/09) — metryki per-node (CPU, memory, disk)
- **kube-state-metrics** — metryki o obiektach K8s (Pod count, Deployment status)

**Loki** (Grafana Labs) — like Prometheus, but for **logs**. Lekki (LogQL podobny do PromQL), kompatybilny z Grafana.

Razem = "darmowy Datadog" dla K8s.

## Prereqs
- K3s / Kind / K3d cluster z odpowiednim resource budget (recommend 4 CPU, 8GB RAM)
- helm
- **Dla Kind**: `kind.yaml` z `bind-address: 0.0.0.0` (żeby Prometheus mógł dotrzeć do controller-manager/scheduler/etcd metrics z poza hosta).

## Pliki

| Plik | Co |
|---|---|
| `kind.yaml` | Cluster config dla Kind z metrics binding na 0.0.0.0 |
| `values.yaml` | Helm values dla kube-prometheus-stack (selector anchors) |
| `service-monitor.yaml` | ServiceMonitor dla aplikacji Python z D1/10 |
| `prometheus-rule.yaml` | PrometheusRule z 2 alertami (HighErrorRate, PodRestartingFrequently) |

## Zadanie

Patrz [`task.md`](./task.md).

## Linki
- [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Loki LogQL](https://grafana.com/docs/loki/latest/logql/)
- [Prometheus Operator CRDs](https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/api.md)
- [AlertManager config examples](https://prometheus.io/docs/alerting/latest/configuration/)

## Cross-link
- D4/07 Trivy Operator → eksportuje metryki o CVE → wizualizacja w Grafanie (dashboard 17813)
- D4/08 Falco → events do Loki (przez Falcosidekick)
- D5/04 GPU → DCGM Exporter dashboard 12239
