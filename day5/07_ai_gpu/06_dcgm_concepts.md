# 06 — DCGM Exporter + Prometheus / Grafana (koncepcje)

> Markdown teoretyczny. fake-gpu-operator dostarcza mock-owany DCGM exporter — można sprawdzić integrację Prometheus, ale wartości metryk są nierealistyczne.

## Co to jest DCGM?

[NVIDIA Data Center GPU Manager](https://developer.nvidia.com/dcgm) — biblioteka do zarządzania i monitorowania flotyły GPU. Eksponuje:
- Wykorzystanie kompute (SM utilization)
- Wykorzystanie pamięci GPU
- Temperatura, power draw, throttling
- ECC errors (krytyczne dla AI workloads — silent corruption)
- NVLink throughput
- Per-process / per-container utilization

[**DCGM Exporter**](https://github.com/NVIDIA/dcgm-exporter) — Prometheus exporter na bazie DCGM. DaemonSet eksportujący metryki na porcie 9400.

## Najważniejsze metryki

| Metryka | Co | Praktyczne użycie |
|---|---|---|
| `DCGM_FI_DEV_GPU_UTIL` | % SM utilization (0-100) | wykrycie idle GPU (= marnowane $) |
| `DCGM_FI_DEV_FB_USED` | Memory used (bytes) | OOM detection przed crash |
| `DCGM_FI_DEV_GPU_TEMP` | Temperatura (°C) | thermal throttling alert (>83°C) |
| `DCGM_FI_DEV_POWER_USAGE` | Watts | cost optimization |
| `DCGM_FI_PROF_PIPE_TENSOR_ACTIVE` | % Tensor Cores active | distinguish "GPU busy" od "GPU robi prawdziwe ML" |
| `DCGM_FI_DEV_NVLINK_BANDWIDTH_TOTAL` | NVLink throughput | bottleneck dla multi-GPU training |
| `DCGM_FI_DEV_ECC_DBE_VOL_TOTAL` | Double-bit ECC errors | sprzętowy fail — wymień GPU |

## Architektura

```
[Pod 1] [Pod 2] [Pod 3]                ← workloads
   ↓       ↓       ↓
   nvidia-smi / CUDA runtime
   ↓
[DCGM library w driver]
   ↓
[DCGM Exporter DaemonSet] :9400/metrics ← Prometheus scrape
   ↓
[Prometheus] (D5/04)
   ↓
[Grafana dashboard 12239 — DCGM Exporter]
[AlertManager] → Slack
```

## Przykładowe Prometheus queries

```promql
# Top 5 idle GPU (utilization < 5% przez 10 min)
topk(5, avg_over_time(DCGM_FI_DEV_GPU_UTIL[10m]) < 5)

# Pod-level GPU utilization (potrzebuje labels merge z kube-state-metrics)
DCGM_FI_DEV_GPU_UTIL * on(uuid) group_left(pod, namespace)
  kube_pod_container_resource_requests{resource="nvidia_com_gpu"}

# GPU memory pressure
DCGM_FI_DEV_FB_USED / DCGM_FI_DEV_FB_TOTAL > 0.95

# Thermal throttling detection
DCGM_FI_DEV_GPU_TEMP > 80
```

## Praktyczne alerty

```yaml
groups:
  - name: gpu-alerts
    rules:
      - alert: GPUIdleLong
        expr: avg_over_time(DCGM_FI_DEV_GPU_UTIL[1h]) < 5
        for: 1h
        annotations:
          summary: "GPU {{ $labels.gpu }} idle przez 1h — kandydat do scale-down lub realokacji"

      - alert: GPUMemoryPressure
        expr: DCGM_FI_DEV_FB_USED / DCGM_FI_DEV_FB_TOTAL > 0.95
        for: 5m
        annotations:
          summary: "GPU {{ $labels.gpu }} >95% memory — ryzyko OOM"

      - alert: GPUECCError
        expr: increase(DCGM_FI_DEV_ECC_DBE_VOL_TOTAL[1h]) > 0
        annotations:
          summary: "GPU {{ $labels.gpu }} double-bit ECC error — zaplanuj wymianę"

      - alert: GPUThrottling
        expr: DCGM_FI_DEV_GPU_TEMP > 83
        for: 10m
        annotations:
          summary: "GPU {{ $labels.gpu }} przegrzanie — performance throttling"
```

## Cost optimization use cases

DCGM metrics są podstawą do:
1. **GPU rightsizing** — czy 4× A100 są naprawdę używane, czy wystarczyłoby 2× ?
2. **Spot/preemptible decisions** — workload <10% utilization ma niski koszt restart, można bezpiecznie deploy na spot
3. **MIG profile selection** — workload używa <1/7 SM → 1g.5gb wystarczy zamiast całego GPU
4. **Idle time billing** — chargeback dla teamów na podstawie GPU-hours used (nie allocated)

## fake-gpu-operator caveat

Mock DCGM exporter generuje **statyczne** lub **randomowe** wartości. Można sprawdzić:
- Pipeline (Prometheus scrapuje, Grafana renderuje, alert się triggeruje)
- Strukturę metryk (sprawdzić nazwy, labels)

NIE można sprawdzić:
- Realnej korelacji (np. utilization vs requests w Pod)
- Faktycznego scenariusza alertowania

W produkcji użyj prawdziwego NVIDIA GPU Operator + DCGM Exporter.

## Linki
- [DCGM Exporter docs](https://github.com/NVIDIA/dcgm-exporter)
- [Grafana dashboard 12239](https://grafana.com/grafana/dashboards/12239-nvidia-dcgm-exporter-dashboard/)
- [DCGM Field Identifiers reference](https://docs.nvidia.com/datacenter/dcgm/latest/dcgm-api/dcgm-api-field-ids.html)
