# 01 — Instalacja fake-gpu-operator

## Cel
Zainstalować fake-gpu-operator emulujący stos NVIDIA na K3d klastrze. Skonfigurować topologię: 2 nody, każdy z 4 GPU obsługujące MIG.

## Zadanie

1. Zlabeluj nody jako "GPU":
   ```bash
   for n in $(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o name); do
     kubectl label "$n" nvidia.com/gpu.product=Tesla-A100 --overwrite
     kubectl label "$n" run.ai/simulated-gpu-node-pool=default --overwrite
   done
   kubectl get nodes --show-labels | head
   ```

2. Instalacja:
   ```bash
   helm install gpu-operator \
     -f topology.yaml \
     --namespace gpu-operator --create-namespace \
     oci://ghcr.io/run-ai/fake-gpu-operator/fake-gpu-operator
   ```

3. Sprawdź pody operatora:
   ```bash
   kubectl get pods -n gpu-operator
   # Spodziewane: status-updater, device-plugin (DaemonSet), kwok controllers
   ```

4. Sprawdź "GPU" na nodach:
   ```bash
   kubectl describe node $(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o name | head -1) | grep -A 5 "Capacity:"
   # Capacity:
   #   cpu:                4
   #   memory:             8Gi
   #   nvidia.com/gpu:     4
   #   pods:               110
   ```

5. Sprawdź DCGM exporter:
   ```bash
   kubectl get svc -n gpu-operator
   # nvidia-dcgm-exporter (port 9400) — Prometheus metrics
   ```

## Pytania kontrolne
1. Co robi `topology.yaml` — od czego zależy liczba GPU per node?
2. Skąd device-plugin "wie" ile GPU jest na node? (Hint: ConfigMap z topology)
3. fake-gpu-operator vs NVIDIA GPU Operator — które komponenty są wspólne?
