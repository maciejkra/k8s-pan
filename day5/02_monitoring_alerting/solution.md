# Solution — 02_monitoring_alerting

## Odpowiedzi

### ServiceMonitor matching

Prometheus Operator używa `serviceMonitorSelector` z chart values żeby wybrać **które** ServiceMonitor's include do config. W values.yaml mamy:
```yaml
prometheus:
  prometheusSpec:
    serviceMonitorSelectorNilUsesHelmValues: false
```

Ten flag = "selektor jest pusty → match WSZYSTKIEGO zamiast nic". Bez: Prometheus ignoruje Twoje `ServiceMonitor` poza chart.

W produkcji: explicitnie dodaj label `release: kube-prometheus-stack` do każdego ServiceMonitor + ustaw `serviceMonitorSelector: { matchLabels: { release: kube-prometheus-stack } }`. Czyściej niż "match all".

### PrometheusRule labels

Label `release: kube-prometheus-stack` (lub dowolny zgodny z `ruleSelector` w values) jest wymagany w **domyślnej** konfiguracji chart. Jak wyżej, możemy to wyłączyć flagą `ruleSelectorNilUsesHelmValues: false`.

Jeśli label BRAK i flag NIE ustawiony → Prometheus **nie widzi** PrometheusRule. `kubectl get prometheusrule` pokaże obiekt, ale Prometheus go nie scrape'uje. Classic "moja reguła istnieje ale nie działa" trap.

Debug:
```bash
kubectl exec -n monitoring prometheus-kube-prometheus-stack-prometheus-0 -c prometheus -- \
  wget -qO- http://localhost:9090/api/v1/rules | jq '.data.groups[].name'
# Lista wszystkich aktywnych grup reguł
```

### node-exporter vs kube-state-metrics

**node-exporter**:
- **Źródło**: host OS (kernel, /proc, /sys, hardware).
- **Metryki**: CPU usage, memory, disk I/O, network, filesystem, temperature (sensors).
- **Obowiązkowe** dla alertów hardware.

**kube-state-metrics**:
- **Źródło**: K8s API server.
- **Metryki**: obiekty K8s — Pod count, Deployment replicas, Cron schedule, Node status.
- **Obowiązkowe** dla alertów K8s (HPA replicas, Pod restart count).

Różnią się abstrakcją: node-exporter = "jak się ma node", KSM = "jak się ma cluster state". Oba potrzebne dla pełnej observability.

### Loki vs Elastic

**Loki**:
- Prostsze (K-V index), tanie (logi + kompresja w S3/GCS).
- LogQL składniowo blisko PromQL — łatwe dla zespołu już znającego Prometheus.
- Brak full-text search w logach (tylko label + grep przez `|= "pattern"`).
- Integracja natywna z Grafana (same labele).

**Elastic Stack (ELK)**:
- Potężny full-text search (Lucene).
- Aggregations (terms, histogram) w Kibana.
- Droższy storage (indeksy na every word).
- Długi historyjnie jako standard dla logów.

Wybór: Loki dla observability-first (labels, metryki), Elastic dla SIEM (security logs, full-text).

### `rate()` vs `increase()` dla alertu

`rate(m[5m])` = średnia per-second w oknie 5 minut. `increase(m[5m])` = różnica (total) w oknie 5 minut.

Dla alertu "error rate > 5%":
- `rate(http_requests_total{status=~"5.."}[5m])` → eventów/s na 5 minut. Normalizuje po czasie.
- `increase(http_requests_total{status=~"5.."}[5m])` → total 5xx eventów w 5min. Nie normalizuje.

**Rate jest odporne na time-series gaps** (brakujące punkty, restart Prometheus). **Increase** może zwrócić 0 przy gap → false negative alert.

Zasada: zawsze `rate()` dla alertów, `increase()` dla business reports ("ile requestów wczoraj").

## Walidacja

```bash
# Po install
kubectl get pods -n monitoring
# Wszystko Running

# ServiceMonitor wczytany
kubectl get servicemonitor -n monitoring python-service-monitor
kubectl exec -n monitoring prometheus-kube-prometheus-stack-prometheus-0 -c prometheus -- \
  wget -qO- http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job=="python-service-monitor")'

# PrometheusRule aktywna
kubectl exec -n monitoring prometheus-kube-prometheus-stack-prometheus-0 -c prometheus -- \
  wget -qO- http://localhost:9090/api/v1/rules | jq '.data.groups[] | select(.name=="app.availability")'

# Grafana access
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Browser: http://localhost:3000 → Dashboards → "Kubernetes / Compute Resources / Cluster"
```

## Troubleshooting

### Prometheus scraping 0 targets

```bash
# UI Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090
# http://localhost:9090/targets → powinno być ~30 targets (kubelet, etcd, itp.)
```

Jeśli 0 → metrics binding nie działa. Sprawdź kind.yaml ma `bind-address: 0.0.0.0`.

### Grafana "Datasource Prometheus zwraca null"

Grafana ustawiona na `http://localhost:9090`. Powinna być **in-cluster** URL:
```
http://kube-prometheus-stack-prometheus.monitoring.svc:9090
```
Zwykle chart ustawia automatycznie. Jeśli nie — edytuj Datasource w UI.

### ServiceMonitor nic nie scrape'uje

```bash
# Sprawdź selector — czy Service ma matching labels?
kubectl get svc python-service -o jsonpath='{.metadata.labels}' | jq
# Oczekiwane: { "app": "python", ... }

# Czy port nazwany "api"?
kubectl get svc python-service -o jsonpath='{.spec.ports}' | jq
# [{ "name": "api", "port": 5002, ... }]
```

Jeśli port NIE nazwany → ServiceMonitor musi mieć numer portu: `targetPort: 5002` (ale preferowane użycie nazwy).

### Loki "too many logs" OOM

Limit retention w `loki-stack` chart values:
```yaml
loki:
  config:
    table_manager:
      retention_period: 168h   # 7 dni
```

## Cross-link

- D2/09 (DaemonSet) — node-exporter jako demo; tutaj Prometheus Operator go ma built-in
- D4/07 (Trivy) — Trivy Operator eksportuje VulnerabilityReport CRD; dashboard Grafana ID 17813
- D4/08 (Falco) — Falcosidekick pisze do Loki
- D5/04 (DCGM GPU) — dashboard 12239 dla GPU metryk
- Presentation slajdy 57-59 (Helm, kube-prometheus-stack, Custom alerts) — teoria tych ćwiczeń
