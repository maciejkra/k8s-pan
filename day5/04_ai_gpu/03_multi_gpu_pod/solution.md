# Solution — 03_multi_gpu_pod

## Odpowiedzi

### Czy 4× GPU = 4 fizyczne GPU?
**Nie zawsze**:
- **Bez time-slicing/MIG** — tak, 4 dedicated GPU
- **Z time-slicing** — może być 4 timeslices na 1-2 fizycznych GPU
- **Z MIG** — może być 4 MIG instances (np. 4× 1g.5gb na jednej A100)

Decyduje konfiguracja device-plugin (per-node), nie sam Pod.

### Multi-GPU na jednym node vs różnych
**Default**: scheduler nie gwarantuje "wszystkie na jednym node". Zazwyczaj 4× GPU na pojedynczym Podzie automatycznie wymusi single-node (bo 1 Pod = 1 node), ale **multi-Pod jobs** (np. PyTorchJob z 4 workers po 1 GPU) mogą lądować na różnych nodach.

Wymuszenie single-node:
```yaml
affinity:
  podAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            workload: training
        topologyKey: kubernetes.io/hostname
```

Wymuszenie multi-node (rozproszone):
```yaml
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        workload: training
```

### Exclusive vs shared
- **Exclusive**: Pod ma dedicated dostęp do GPU. Nikt inny nie może używać tego GPU. Default w K8s.
- **Shared (time-slicing)**: kilka Podów współdzieli GPU. Każdy widzi pełną pamięć GPU, ale dostaje tylko 1/N czasu kompute. Konfiguracja:
  ```yaml
  # ConfigMap dla device-plugin
  sharing:
    timeSlicing:
      resources:
        - name: nvidia.com/gpu
          replicas: 4                  # 1 fizyczne GPU = 4 wirtualne
  ```
  Workload pyta `nvidia.com/gpu: 1`, dostaje "1/4 fizycznego". Ważne: aplikacja musi tolerować inne procesy walczące o pamięć/kompute.
- **Shared (MIG)**: hardware partitioning A100/H100. Każdy MIG instance jest "mini-GPU" z dedicated SMs i pamięcią. Bezpieczniejsze niż time-slicing.

## Walidacja

```bash
# Multi-GPU Pod scheduled
kubectl describe pod multi-gpu-job | grep -E "Node:|gpu"

# Wszystkie GPU na node są zajęte
NODE=$(kubectl get pod multi-gpu-job -o jsonpath='{.spec.nodeName}')
kubectl describe node $NODE | grep -A 1 "nvidia.com/gpu"
# Allocated resources:
#   nvidia.com/gpu:  4 (100%)

# Drugi Pod 4×GPU na drugim node lub Pending
kubectl get pods -l workload=training -o wide
```
