# Solution — 03_metrics_server

## Odpowiedzi

### Dlaczego HPA wymaga metrics-server?

HPA pyta API `metrics.k8s.io/v1beta1` o aktualne zużycie CPU/memory per Pod. To API jest **dostarczane przez metrics-server** (wcześniej Heapster — deprecated).

Bez metrics-server: `kubectl get hpa` pokazuje `TARGETS: <unknown>/50%` — HPA nie wie ile Pod używa, nie może policzyć czy skalować.

HPA **nie czyta** Prometheusa natywnie. Jeśli chcesz custom metrics (np. requests/s) — potrzebujesz **Prometheus Adapter** + API `custom.metrics.k8s.io`. Cross-link D5/02 + D5/04.

### Historia zużycia CPU (>3h temu)

Metrics-server trzyma tylko point-in-time (ostatnie ~2 próbki, wystarcza dla HPA decyzji). Do historii:

- **Prometheus** (D5/02) — skrapuje metrics z kubelet (`/metrics/resource`, `/metrics/cadvisor`). Trzyma zwykle 2 tygodnie, można dłużej z Thanos/Mimir/VictoriaMetrics.
- **Grafana Cloud / Datadog / New Relic** — SaaS, zwykle 13 miesięcy.
- **VPA** (Vertical Pod Autoscaler) — samo VPA rekomenduje requests na podstawie historii (wymaga Prometheus albo własnego recorder).

### `kubectl top pod X --containers`

Rozbicie zużycia per kontener (dla Pod multi-container). Bez `--containers` pokazuje sumę Pod.

```bash
kubectl top pod my-app --containers
# POD      NAME        CPU(cores)  MEMORY(bytes)
# my-app   main        50m         128Mi
# my-app   sidecar     5m          20Mi
```

Użycie: identyfikacja który kontener w Pod Multi-container ciągnie resources (np. Vault Agent sidecar vs main app).

### Node-exporter vs metrics-server

| | metrics-server | node-exporter |
|---|---|---|
| Co mierzy | **Pod + Node CPU/memory** (agregat z kubelet cAdvisor) | **szczegółowe metryki systemowe hosta** (disk I/O, network, filesystem, hardware) |
| Data model | API `metrics.k8s.io/v1beta1` (JSON, point-in-time) | Prometheus exposition format (`/metrics`, HTTP text) |
| Retention | 0 (live) | 0 (exposes current values, Prometheus retains) |
| Zasilanie | HPA, `kubectl top` | Prometheus alerts, Grafana dashboards |

Są komplementarne — metrics-server dla K8s scheduler/HPA, node-exporter dla SRE observability.

### Guaranteed CPU% interpretacja

`CPU%` w `kubectl top node` = `(cpu cores used) / (total allocatable cores)` na node.

Dla Pod `kubectl top pod`: pokazuje **cores used** (absolute), nie %. Pod z `limits.cpu: 500m` używający 100m = 20% wykorzystania **limita**. K8s pokazuje `100m`, musisz policzyć sam.

## Walidacja

```bash
kubectl top nodes
kubectl top pods -A | head -10

# HPA będzie widział metryki:
kubectl get hpa -A
# Nie więcej <unknown> (jeśli HPA już istnieje)

# Check logów metrics-server (gdyby coś szło źle)
kubectl logs -n kube-system deploy/metrics-server --tail=30
```

## Troubleshooting

### `error: Metrics API not available`

Metrics-server nie zbiera jeszcze danych (potrzebuje 2 próbek, ~30s po starcie). Poczekaj.

### `unable to fetch pod metrics for pod X: no metrics known for pod`

Pod istnieje <30s — metrics-server jeszcze go nie zobaczył. Poczekaj.

### `E1210 x509: certificate signed by unknown authority`

Brak `--kubelet-insecure-tls`. Re-patch:
```bash
kubectl edit deploy -n kube-system metrics-server
# Dodaj args
```

### `Failed to scrape node X: ... connection refused`

`--kubelet-preferred-address-types` nie zawiera typu który node ma. Dla Kind zwykle `Hostname` lub `InternalIP`. Dodaj wszystkie:
```
--kubelet-preferred-address-types=InternalIP,Hostname,ExternalIP
```

### K3s — metrics-server już jest ale `kubectl top` nie działa

```bash
kubectl get pods -n kube-system | grep metrics
```
Jeśli widzisz `metrics-server-xxx` Running → wszystko OK, tylko nie pod typowym Deployment-em (może być `helm` albo `manifests/`).

Jeśli w CrashLoopBackOff → `kubectl logs -n kube-system metrics-server-xxx` → najczęściej te same problemy z TLS co wyżej.

## Cross-link

- D3/04 (HPA) — pierwszy konsument metrics-server
- D5/02 (Prometheus + Grafana) — długoterminowa historia
- D5/04 (GPU metrics) — DCGM exporter używa modelu podobnego do node-exportera, skrapowany przez Prometheus
- D2/09 (DaemonSet) — node-exporter jako demo DS
