# 04 — AI / GPU na Kubernetes (z fake-gpu-operator)

## Cel
Zrozumieć i przećwiczyć **scheduling GPU** w K8s — bez konieczności posiadania fizycznych GPU. Używamy [fake-gpu-operator](https://github.com/run-ai/fake-gpu-operator) (Run:AI), który emuluje cały stos NVIDIA na CPU-only klastrze.

## Co działa w fake mode
✅ Cała logika schedulingu (`resources.limits.nvidia.com/gpu`)
✅ MIG profile deklaratywnie
✅ Multi-GPU per Pod
✅ **Time-slicing** (wirtualne GPU)
✅ Taints/tolerations dla GPU node pools
✅ Prometheus metrics (DCGM exporter — wartości mock-owane)
✅ NVIDIA Device Plugin emulation

## Co NIE działa
❌ Faktyczne obliczenia (nvidia-smi pokaże mock topology)
❌ Realne GPU utilization w DCGM (procentowe wartości są stałe lub randomowe)
❌ CUDA workloads (uruchomią się tylko jeśli obraz nie sprawdza GPU drivers)

**Wniosek**: idealne do nauki K8s aspektów. Niedostępne dla benchmarkingu / ML training.

## Plan dnia GPU

| Krok | Katalog | Co |
|---|---|---|
| 1 | `01_install_fake_gpu/` | Helm install fake-gpu-operator + ConfigMap topologii (2 nody × 4 GPU × MIG) |
| 2 | `02_gpu_pod/` | Pod z `nvidia.com/gpu: 1`, scheduled na fake GPU node |
| 3 | `03_multi_gpu_pod/` | Pod z 4× GPU |
| 4 | `04_mig_demo/` | MIG profile deklaratywnie (1g.5gb, 3g.20gb) |

## GPU sharing — 3 modele

W produkcji jedno GPU może być **współdzielone** między wieloma workloadami. Trzy mechanizmy:

### 1. Time-slicing (software multiplexing)
Jedno fizyczne GPU emuluje N "wirtualnych" — każdy proces dostaje `1/N` czasu kompute. Wszystkie współdzielą **całą pamięć GPU**.

```yaml
# ConfigMap dla NVIDIA Device Plugin
apiVersion: v1
kind: ConfigMap
metadata: { name: time-slicing-config }
data:
  any: |
    version: v1
    sharing:
      timeSlicing:
        resources:
          - name: nvidia.com/gpu
            replicas: 4               # 1 fizyczne GPU = 4 wirtualne
```

Pod pyta `nvidia.com/gpu: 1` — dostaje 1/4 czasu kompute, ale widzi pełną pamięć (10/20/40GB).

✅ Najprostsze, działa na każdej karcie NVIDIA
❌ Brak izolacji pamięci — proces może OOM-killnąć siebie albo sąsiada
❌ Nieprzewidywalny performance (kontekst switching)

**Use cases**: dev/test, inference małych modeli, Jupyter notebooks deweloperów.

### 2. MIG — Multi-Instance GPU (hardware partitioning)

Tylko Ampere (A100, A30) i Hopper (H100). Hardware-level podział na izolowane "mini-GPU".

```yaml
resources:
  limits:
    nvidia.com/mig-1g.5gb: 1          # 1/7 SM, 5GB pamięci, dedicated
```

✅ Hardware izolacja (jeden instance crash nie wpływa na resztę)
✅ Predictable performance
❌ Tylko Ampere/Hopper
❌ Statyczna geometria (zmiana wymaga drain + reconfigure)

**Use cases**: produkcja inference, multi-tenant ML platform.

### 3. MPS — Multi-Process Service (NVIDIA proprietary)

CUDA processes współdzielą jeden GPU context. Lepsze niż time-slicing dla compute-bound workloads.

```yaml
sharing:
  mps:
    replicas: 4
```

✅ Mniejszy overhead niż time-slicing
❌ Wymaga `nvidia-cuda-mps-control` daemon na node
❌ Specyficzne dla CUDA

→ Patrz **`04_mig_demo/`** dla pełnego ćwiczenia MIG.

## Prereqs
- K3d cluster (`./setup-cluster.sh`) z **co najmniej 2 agent nodes**
- Helm

## Quick start

```bash
# 1. Instalacja fake-gpu-operator (chart 0.0.55+, sprawdzono na 0.0.80)
cd 01_install_fake_gpu
helm install gpu-operator -f topology.yaml --create-namespace -n gpu-operator \
  oci://ghcr.io/run-ai/fake-gpu-operator/fake-gpu-operator

# 2. Label workerów (szczegóły w 01_install_fake_gpu/README.md)
for n in $(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o name); do
  kubectl label "$n" run.ai/simulated-gpu-node-pool=default --overwrite
  kubectl label "$n" nvidia.com/gpu.product=NVIDIA-A100-SXM4-40GB --overwrite
done
kubectl wait --for=condition=Ready -n gpu-operator pod -l app=device-plugin --timeout=3m

# 3. Sprawdź "GPU" na nodach
kubectl describe nodes | grep -A 2 "Capacity:" | grep nvidia
# nvidia.com/gpu: 4

# 4. Uruchom workload
kubectl apply -f ../02_gpu_pod/pod.yaml
kubectl describe pod gpu-workload | grep -A 5 "Limits:"
```

## Tematy "tylko prezentacja"

Pełne omówienie w slajdach D5 (sekcja 10 agendy):
- **Kueue** — job queueing dla AI/ML (ResourceFlavor → ClusterQueue → Workload)
- **DCGM Exporter** — metryki GPU dla Prometheus (utilization, memory, ECC errors, throttling)
- **GPU production practices** — dedicated node pools, spot instances, Karpenter, image preloading (Spegel)

## Linki
- [fake-gpu-operator](https://github.com/run-ai/fake-gpu-operator) — Run:AI emulator
- [NVIDIA GPU Operator (real)](https://github.com/NVIDIA/gpu-operator) — produkcyjny stack
- [Time-slicing GPUs in K8s](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/gpu-sharing.html)
- [MIG User Guide](https://docs.nvidia.com/datacenter/tesla/mig-user-guide/)
- [Kubernetes scheduling reference](https://kubernetes.io/docs/concepts/scheduling-eviction/)
