# 07 — AI / GPU na Kubernetes (z fake-gpu-operator)

## Cel
Zrozumieć i przećwiczyć **scheduling GPU** w K8s — bez konieczności posiadania fizycznych GPU. Używamy [fake-gpu-operator](https://github.com/run-ai/fake-gpu-operator) (Run:AI), który emuluje cały stos NVIDIA na CPU-only klastrze.

## Co działa w fake mode
✅ Cała logika schedulingu (`resources.limits.nvidia.com/gpu`)
✅ MIG profile deklaratywnie
✅ Multi-GPU per Pod
✅ Time-slicing (wirtualne GPU)
✅ Taints/tolerations dla GPU node pools
✅ Prometheus metrics (DCGM exporter — wartości mock-owane)
✅ NVIDIA Device Plugin emulation

## Co NIE działa
❌ Faktyczne obliczenia (nvidia-smi pokaże mock topology)
❌ Realne GPU utilization w DCGM (procentowe wartości są stałe lub randomowe)
❌ CUDA workloads (uruchomią się tylko jeśli obraz nie sprawdza GPU drivers)

**Wniosek**: idealne do nauki K8s aspektów. Niedostępne dla benchmarkingu / ML training.

## Plan dnia GPU

| Krok | Katalog / plik | Co |
|---|---|---|
| 1 | `01_install_fake_gpu/` | Helm install fake-gpu-operator + ConfigMap topologii (2 nody × 4 GPU × MIG) |
| 2 | `02_gpu_pod/` | Pod z `nvidia.com/gpu: 1`, scheduled na fake GPU node |
| 3 | `03_multi_gpu_pod/` | Pod z 4× GPU |
| 4 | `04_mig_demo/` | MIG profile deklaratywnie (1g.5gb, 3g.20gb) |
| 5 | `05_kueue_intro.md` | Markdown: Kueue jako job queue dla AI/ML |
| 6 | `06_dcgm_concepts.md` | Markdown: DCGM Exporter + Prometheus queries |
| 7 | `07_production_practices.md` | Markdown: node pools, spot, autoscaling |

## Prereqs
- K3d cluster (`./setup-cluster.sh`) z **co najmniej 2 agent nodes**
- Helm

## Quick start

```bash
# 1. Instalacja fake-gpu-operator
cd 01_install_fake_gpu
helm install gpu-operator -f topology.yaml --create-namespace -n gpu-operator \
  oci://ghcr.io/run-ai/fake-gpu-operator/fake-gpu-operator
kubectl wait --for=condition=Ready -n gpu-operator pod -l app=device-plugin --timeout=3m

# 2. Sprawdź "GPU" na nodach
kubectl describe nodes | grep -A 2 "Capacity:" | grep nvidia
# nvidia.com/gpu: 4

# 3. Uruchom workload
kubectl apply -f ../02_gpu_pod/pod.yaml
kubectl describe pod gpu-workload | grep -A 5 "Limits:"
```

## Linki
- [fake-gpu-operator](https://github.com/run-ai/fake-gpu-operator) — Run:AI emulator
- [NVIDIA GPU Operator (real)](https://github.com/NVIDIA/gpu-operator) — produkcyjny stack
- [Kubernetes scheduling reference](https://kubernetes.io/docs/concepts/scheduling-eviction/)
