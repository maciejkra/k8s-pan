# Solution — 02_gpu_pod

## Odpowiedzi

### Requests = Limits dla nvidia.com/gpu
GPU to **extended resource**. K8s API wymaga, żeby dla extended resources `requests == limits` (lub tylko `limits` ustawione, wtedy `requests` jest auto-uzupełniany). Powód:
- GPU nie da się "burst" — jak masz, masz; jak nie masz, czekasz
- Brak wsparcia dla cgroup-based limiting GPU jak dla CPU/memory
- MIG i time-slicing wprowadzają dyskretne jednostki

### Pod z więcej GPU niż na pojedynczym node
```yaml
resources:
  limits:
    nvidia.com/gpu: 8                  # nasze nody mają tylko 4
```
Pod zostanie **Pending** na zawsze. Scheduler nie potrafi rozłożyć extended resource na wiele nodów (przeciwnie do np. memory, gdzie też nie potrafi — to **per-pod** decision).

`kubectl describe pod` → `Events: 0/3 nodes are available: 3 Insufficient nvidia.com/gpu`.

Dla multi-node GPU workload (training rozproszony) używa się np. **MPI Operator** lub **PyTorch Operator** które tworzą *wiele Podów* (każdy 1× GPU lub N×GPU per node), połączonych przez NCCL/RDMA.

### Spread GPU workload
```yaml
spec:
  topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: kubernetes.io/hostname
      whenUnsatisfiable: DoNotSchedule
      labelSelector:
        matchLabels:
          app: gpu-test
```

Bez tego: scheduler może umieścić wszystkie 4 GPU Pody na jednym node (greedy). Z tym: rozprasza po nodach.

## Walidacja

```bash
# Pod scheduled
kubectl get pod gpu-workload -o wide
# NAME           READY   STATUS    RESTARTS   AGE   IP           NODE
# gpu-workload   1/1     Running   0          10s   10.42.1.5    k3d-training-agent-0

# Allocated GPU widoczne
kubectl describe node k3d-training-agent-0 | grep -A 1 "nvidia.com/gpu"
# Capacity:
#   nvidia.com/gpu:  4
# Allocatable:
#   nvidia.com/gpu:  4
# Allocated resources:
#   nvidia.com/gpu:  1 (25%)
```
