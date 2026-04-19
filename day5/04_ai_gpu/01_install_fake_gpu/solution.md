# Solution — 01_install_fake_gpu

## Odpowiedzi

### topology.yaml
Definiuje per-nodePool ile fake GPU i jakiego typu. fake-gpu-operator generuje:
- Patch dla każdego node z labelami `nvidia.com/gpu.product`, `nvidia.com/gpu.memory`
- Patch `Capacity.nvidia.com/gpu = N`
- ConfigMap dla device-plugin z mapowaniem `gpu-id → fake serial`

Zmiana `gpuCount: 4 → 8` + `helm upgrade` natychmiast zmieni capacity (patch jest re-aplikowany).

### Skąd device-plugin zna liczbę GPU
fake-gpu-operator generuje per-node ConfigMap `topology-<node-name>` z listą fake-GPU. Device-plugin (DaemonSet) montuje ConfigMap, parsuje, raportuje przez `ListAndWatch` gRPC do kubelet.

W realu: NVIDIA Device Plugin używa `nvml` (NVIDIA Management Library) żeby wykryć fizyczne GPU.

### Wspólne komponenty fake vs real
| Komponent | fake-gpu | real |
|---|---|---|
| Device Plugin (gRPC do kubelet) | mock | NVIDIA k8s-device-plugin |
| MIG manager | mock | NVIDIA mig-manager |
| DCGM exporter | mock metrics | nvidia-dcgm-exporter (real metrics) |
| GPU Feature Discovery | mock labels | NVIDIA GFD |
| Container Toolkit | nie ma | nvidia-container-toolkit (mounts CUDA libs) |
| Driver | nie ma | nvidia-driver-daemonset |

Konsekwencja: fake-gpu pokazuje **jak** się pisze manifesty (deployments z `nvidia.com/gpu`, MIG strategies, time-slicing). Real-gpu dodaje warstwę faktycznego runtime.

## Walidacja

```bash
# Sprawdź labele node
kubectl get nodes -L nvidia.com/gpu.product,nvidia.com/gpu.memory

# Test scheduling — Pod z requestem GPU powinien być Pending dopóki fake-gpu nie wstanie
kubectl run test-gpu --image=busybox --restart=Never --rm -it \
  --overrides='{"spec":{"containers":[{"name":"test","image":"busybox","resources":{"limits":{"nvidia.com/gpu":"1"}}}]}}' \
  -- sh -c "echo OK"
```

Przed instalacją fake-gpu-operator: pod Pending z `Insufficient nvidia.com/gpu`.
Po instalacji: pod Running.
