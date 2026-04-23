# Solution — 04_HPA

## Odpowiedzi

### Wzór HPA

`desiredReplicas = ceil(currentReplicas × currentMetric / targetMetric)`

Dla: 2 Pody × 150m avg CPU, requests 200m, target 50% utilization:

- `currentMetric = 150/200 = 75%`
- `targetMetric = 50%`
- `desiredReplicas = ceil(2 × 75/50) = ceil(3.0) = 3`

Po skalowaniu do 3 Pod-ów (jeśli load stały): `new avg = 100m per pod (300m total / 3)`, utilization = `100/200 = 50%` → dokładnie target, HPA nie skaluje dalej.

### Scale-up vs scale-down asymmetry

- **Scale-up agresywny** — gdy aplikacja jest pod obciążeniem, każda sekunda zwłoki = latency użytkowników. Lepiej "za szybko za dużo" niż "za wolno wystarczająco".
- **Scale-down powolny** — metryki CPU fluktuują (garbage collection, scheduled tasks). Szybki scale-down → ciągłe flapowanie ("yo-yo"). 5min stabilization = "jeśli ruch naprawdę spadł, to spadł".

Dodatkowo: kill Poda przy scale-down = stracone in-flight requests (chyba że masz graceful shutdown + preStop hook).

### `stabilizationWindowSeconds: 0` dla scaleUp — kiedy źle

- Gdy metryka **szybko zmienia się** (np. cron-based burst co 5min, batch jobs co minutę).
- Każdy peak → natychmiastowy scale-up → zaraz potem peak mija → po 5min scaleDown → cykl.

Rozwiązania:
- **`stabilizationWindowSeconds: 60`** dla scaleUp → "skaluj tylko jeśli metryki są wysokie ≥60s".
- **Pred alternative metrics** (requests/s zamiast CPU) — bardziej stabilne dla burst workloadów.
- **KEDA** zamiast HPA — event-driven autoscaling z natywnym debouncing.

### Custom metrics — 2 sposoby

1. **Prometheus Adapter** (`custom.metrics.k8s.io`) — rejestruje Prometheus queries jako K8s custom metrics. HPA używa `type: Pods` albo `type: Object` z nazwą zwróconą przez adapter. Typowe: `http_requests_per_second`, `queue_depth`.
2. **External Metrics Provider** (`external.metrics.k8s.io`) — dla metryk spoza klastra (AWS CloudWatch, GCP Monitoring). Adapter per cloud. Typowe: SQS queue length, Pub/Sub pending.

Format HPA:
```yaml
metrics:
- type: Pods
  pods:
    metric: { name: http_requests_per_second }
    target: { type: AverageValue, averageValue: "100" }
```

### HPA na memory — trudności

1. **Memory rzadko zwalnia sama** — aplikacja alokuje heap, nie zwraca do OS (JVM, Node.js, Python). HPA widzi wysokie memory permanentnie, chce scale-up, ale scale nic nie zmieni.
2. **OOM zamiast plateau** — aplikacja przekraczająca `limits.memory` = OOMKilled, nie throttled. HPA nie widzi OOM — widzi tylko bieżące memory żyjących Pod-ów.
3. **Alternative: scale by heap utilization** (JMX metric) — wymaga custom metrics adapter.

Pragmatyka: HPA na memory tylko gdy aplikacja **faktycznie** zwraca memory (np. cache). Dla JVM/Node.js lepiej: HPA na CPU + VPA na memory (rekomendacje requests).

## Walidacja

```bash
kubectl apply -f hpa/
sleep 30
kubectl get hpa
# TARGETS: 1%/50% (idle)

# Load w drugim terminalu
kubectl run load --image=busybox:1.37 --restart=Never -- \
  /bin/sh -c "while sleep 0.01; do wget -q -O- http://php-apache; done"

# Obserwuj
kubectl get hpa --watch
# Po 30-60s: TARGETS rośnie, REPLICAS 1→3→5→...
```

Spodziewany pattern (2-CPU K3d):
- t=0: 1 Pod, 1% CPU
- t=30: load starts, 1 Pod 100% CPU (bo 200m request, używa 500m limit)
- t=60: HPA widzi 100%/50% = 2× → scale do 2, potem 3
- t=90: CPU per Pod spada, HPA plateau ~4-5 replik
- load off: t=60 po zatrzymaniu → scale-down zaczyna (behavior scaleDown)
- t=180 po zatrzymaniu: 1 replika

## Troubleshooting

### `TARGETS: <unknown>/50%`

Metrics-server nie działa albo nie ma jeszcze metryk:
```bash
kubectl top pods -l run=php-apache
# Jeśli brak: patrz D3/03
```

### HPA nie skaluje mimo wysokiego CPU

- `maxReplicas` osiągnięty — sprawdź `kubectl get hpa`.
- `stabilizationWindowSeconds: 0` dla scaleUp, ale policy: type=Percent value=100 → skala co 15s z 1 do 2. Czekaj.
- Tolerancja HPA ±10%: jeśli `currentMetric/targetMetric < 1.1`, HPA nie ruszy. Dla bardzo małej różnicy HPA zaokrąglą do obecnych replik.

### `failed to get cpu utilization: unable to get metrics for resource cpu`

Pod musi mieć `requests.cpu` zdefiniowany, inaczej utilization = undefined. Sprawdź:
```bash
kubectl get pod -l run=php-apache -o jsonpath='{.items[0].spec.containers[0].resources.requests}'
```

### Scale-down oscyluje

`stabilizationWindowSeconds` za krótki dla Twojej aplikacji. Zwiększ do 120s lub więcej. Albo: zmień metryki z CPU na bardziej stabilne (requests/s).

## Cross-link

- D3/03 (Metrics Server) — wymagana zależność
- D5/02 (Prometheus Adapter) — custom metrics dla HPA
- D5/04 (GPU) — GPU HPA wymaga DCGM metrics + Prometheus Adapter
- D3/07 (PriorityClass) — HPA tworzy nowe Pody z pewnym priority; preemption może ich się pozbyć
