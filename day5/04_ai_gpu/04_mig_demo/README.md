# 04 — MIG (Multi-Instance GPU)

## Cel
Zobaczyć MIG profile w działaniu — jak jedno fizyczne A100 (80GB) jest dzielone na mniejsze "GPU instances" (1g.10gb, 2g.20gb itp.).

## Kontekst
**MIG** (NVIDIA Multi-Instance GPU) — hardware partitioning GPU z architektury Ampere (A100, A30) i Hopper (H100). Jedno GPU dzieli się na 1-7 niezależnych "instances", każdy ma:
- Dedicated SMs (Streaming Multiprocessors)
- Dedicated memory
- Dedicated cache, NVLink lanes
- Hardware-level isolation (jeden instance crash nie wpływa na pozostałe)

**MIG vs time-slicing vs MPS**:
- **Time-slicing**: software multiplexing, brak izolacji pamięci, pełne GPU memory dla każdego procesu (walka)
- **MIG**: hardware partitioning, izolowane, predictable performance — tylko A100/A30/H100
- **MPS (Multi-Process Service)**: CUDA processes share context, mniej overhead niż time-slicing, ale CUDA-only

**Oficjalne profile A100 (80GB)** — NVIDIA MIG geometry:

| Profile | Compute (SMs) | Memory | Max instances per GPU | Use case |
|---|---|---|---|---|
| 1g.10gb | 1/7 | 10 GB | 7 | inference małych modeli (BERT, ResNet) |
| 2g.20gb | 2/7 | 20 GB | 3 | inference średnich (Llama 7B int8) |
| 3g.40gb | 3/7 | 40 GB | 2 | fine-tuning małych modeli |
| 4g.40gb | 4/7 | 40 GB | 1 | fine-tuning średnich |
| 7g.80gb | 7/7 (cały) | 80 GB | 1 | training od zera, multi-node |

Dla A100 40GB: `1g.5gb`, `2g.10gb`, `3g.20gb`, `4g.20gb`, `7g.40gb`. Nasz `topology.yaml` używa 40GB geometry (`1g.5gb`, `3g.20gb`) — fake-gpu-operator symuluje.

**Uwaga**: profile `1g.20gb` NIE istnieje w oficjalnej specyfikacji NVIDIA — compute × memory są związane geometrią MIG.

## Pliki

- `mig-1g-pods.yaml` — 3 Pody po 1 instance 1g.5gb (małe inference)
- `mig-3g-pod.yaml` — 1 Pod 3g.20gb (większy workload)

## Zadanie

Pełne kroki w [`task.md`](./task.md). Skrót:

1. **Najpierw** patch capacity nodów (`task.md` Część 0) — `fake-gpu-operator` nie eksponuje `nvidia.com/mig-*` automatycznie, w realnym klastrze robi to NVIDIA GPU Operator po `mig-mode=enabled`.

2. Wdroż 3 Pody po 1g.5gb (małe inference):
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
   # nvidia.com/mig-1g.5gb        3   7
   # nvidia.com/mig-3g.20gb       1   2
   ```

5. Sprzątnij:
   ```bash
   kubectl delete pod -l mig-demo=true
   ```

## Pytania kontrolne

1. MIG jest **statyczny** czy **dynamiczny**? (Czy można w runtime zmienić profile? Hint: MIG rekonfiguracja wymaga `nvidia-smi mig -cgi` i NO active processes.)
2. Strategy `single` vs `mixed` — jaka różnica? (`single`: tylko jeden profile per node; `mixed`: różne profile równocześnie.)
3. Co się stanie jeśli żaden node nie ma profile `nvidia.com/mig-3g.40gb` a Pod o niego prosi? (Pending, Insufficient.)
4. Jak monitorować utilization MIG instances? (Hint: DCGM exporter z metryką `DCGM_FI_DEV_GPU_UTIL` per MIG UUID.)
5. **Bonus**: dlaczego MIG nie działa na consumer GPU (RTX, A10, L40)? (Hint: hardware feature tylko A100/A30/H100.)
