# 01 — Instalacja fake-gpu-operator

## Cel
Zainstalować fake-gpu-operator emulujący stos NVIDIA na K3d klastrze. Skonfigurować topologię: 2 nody, każdy z 4 GPU obsługujące MIG.

## Zadanie

1. Instalacja chart-a:
   ```bash
   helm install gpu-operator \
     -f topology.yaml \
     --namespace gpu-operator --create-namespace \
     oci://ghcr.io/run-ai/fake-gpu-operator/fake-gpu-operator
   ```

2. Zlabeluj workery jako "GPU node pool":
   ```bash
   for n in $(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o name); do
     # Wymagane: chart przypisuje nody do nodePool przez ten label
     kubectl label "$n" run.ai/simulated-gpu-node-pool=default --overwrite
     # gpu.product label — musi zawierać "40GB"/"80GB" dla mig-faker (D5/04/04 MIG demo).
     # Na innym hardware: NVIDIA-A100-SXM4-80GB / NVIDIA-A100-PCIE-40GB / NVIDIA-H100-SXM5-80GB.
     kubectl label "$n" nvidia.com/gpu.product=NVIDIA-A100-SXM4-40GB --overwrite
   done
   kubectl get nodes --show-labels | head
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
