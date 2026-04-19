# 04 — MIG (Multi-Instance GPU)

## Cel
Zobaczyć MIG profile w działaniu — jak jedno fizyczne A100 (80GB) jest dzielone na mniejsze "GPU instances" (1g.5gb, 3g.20gb itp.).

## Kontekst
**MIG** (NVIDIA Multi-Instance GPU) — hardware partitioning GPU z architektury Ampere (A100, A30) i Hopper (H100). Jedno GPU dzieli się na 1-7 niezależnych "instances", każdy ma:
- Dedicated SMs (Streaming Multiprocessors)
- Dedicated memory (np. 5GB / 10GB / 20GB / 40GB)
- Dedicated cache, NVLink lanes
- Hardware-level isolation (jeden instance crash nie wpływa na pozostałe)

**MIG vs time-slicing**:
- Time-slicing: software multiplexing, brak izolacji pamięci, pełne GPU memory dla każdego procesu (walka)
- MIG: hardware partitioning, izolowane, predictable performance

**Profile A100 (80GB)**:
| Profile | Compute (SMs) | Memory | Max instances |
|---|---|---|---|
| 1g.10gb | 1/7 | 10 GB | 7 |
| 1g.20gb | 1/7 | 20 GB | 4 |
| 2g.20gb | 2/7 | 20 GB | 3 |
| 3g.40gb | 3/7 | 40 GB | 2 |
| 4g.40gb | 4/7 | 40 GB | 1 |
| 7g.80gb | 7/7 (cały) | 80 GB | 1 |

## Zadanie

1. Sprawdź zaawansowaną topology (z 01_install_fake_gpu mamy `mig.enabled: true`):
   ```bash
   kubectl get nodes -o yaml | yq '.items[].status.capacity' | grep mig
   # nvidia.com/mig-1g.5gb: 7
   # nvidia.com/mig-3g.20gb: 2
   ```

2. Wdroż 7 Podów po 1g.5gb (małe inference):
   ```bash
   kubectl apply -f mig-1g-pods.yaml
   kubectl get pods -l mig-profile=1g.5gb
   ```

3. Wdroż 1 Pod 3g.20gb (większy training):
   ```bash
   kubectl apply -f mig-3g-pod.yaml
   ```

4. Sprawdź alokację:
   ```bash
   NODE=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o name | head -1 | cut -d/ -f2)
   kubectl describe node $NODE | grep -A 10 "Allocated resources"
   ```

5. Sprzątnij:
   ```bash
   kubectl delete pod -l mig-demo=true
   ```

## Pytania kontrolne
1. MIG jest **statyczny** czy **dynamiczny**? (Czy można w runtime zmienić profile?)
2. Strategy `single` vs `mixed` — jaka różnica?
3. Co się stanie jeśli żaden node nie ma profile `nvidia.com/mig-3g.40gb` a Pod o niego prosi?
4. Jak monitorować utilization MIG instances? (Hint: DCGM exporter — D5/07/06)
