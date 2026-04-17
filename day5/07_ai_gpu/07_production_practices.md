# 07 — Praktyki produkcyjne dla GPU na K8s

## Dedykowane node pools

GPU node są drogie ($2-30/h). Nie chcesz, żeby jakiś `nginx` zajmował slot.

**Pattern**: dedicated node pool + taints + tolerations.

```bash
# Cluster autoscaler / Karpenter / EKS managed nodegroup z labelem:
kubectl label node $GPU_NODE nvidia.com/gpu.present=true
kubectl taint node $GPU_NODE nvidia.com/gpu=true:NoSchedule
```

```yaml
# Pod toleruje taint i preferuje GPU node
spec:
  nodeSelector:
    nvidia.com/gpu.present: "true"
  tolerations:
    - key: nvidia.com/gpu
      operator: Exists
      effect: NoSchedule
  containers:
    - name: app
      resources:
        limits: { nvidia.com/gpu: 1 }
```

Workload bez `nvidia.com/gpu` w resources nie ma jak ominąć taint → nie wyląduje na GPU node.

## Spot / Preemptible instances

GPU spot instances (AWS, GCP) potrafią być **70-90% taniej** niż on-demand.

✅ **Tak dla**:
- Training (checkpointing co N minut)
- Batch inference offline
- Hyperparameter sweep (jeden run pada → inny robi się dalej)

❌ **Nie dla**:
- Real-time inference (SLA latency)
- Distributed training bez checkpointing (1 padający node = restart całego joba)
- Workloads bez retry logic

**Implementation**:
```yaml
# Karpenter NodePool z spot
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: gpu-spot
spec:
  template:
    spec:
      requirements:
        - { key: karpenter.sh/capacity-type, operator: In, values: [spot] }
        - { key: node.kubernetes.io/instance-type, operator: In,
            values: [g5.xlarge, g5.2xlarge, p3.2xlarge] }
      taints:
        - { key: nvidia.com/gpu-spot, effect: NoSchedule }
```

```yaml
# Pod toleruje spot taint + handle interruption (PodDisruptionBudget + checkpointing)
spec:
  tolerations:
    - { key: nvidia.com/gpu-spot, operator: Exists, effect: NoSchedule }
```

Pre-emption notification: AWS daje 2 min, GCP 30s. Aplikacja powinna nasłuchiwać:
```
kubelet shutdown signal → SIGTERM → trap → save checkpoint → exit
```

## Autoscaling GPU node pools

### Cluster Autoscaler (CA)
- Klasyczny, działa per AWS ASG / GCP MIG
- **Wolny** dla GPU — node startup może trwać 5-10 min (pull GPU driver image, init device-plugin)
- Może zostawić zombie nodes (idle GPU)

### Karpenter
- Provisioning bezpośrednio przez cloud API (bypass ASG)
- Szybszy startup (~2-3 min)
- Bin-packing aware — wybiera najmniejszy node który zmieści Pending Pody
- Lepszy dla GPU bo:
  - Multiple instance types per NodePool (jeśli `g5.xlarge` brak, próbuje `g5.2xlarge`)
  - Native support dla spot z fallback na on-demand
  - Consolidation — wykrywa gdy można skondensować workloads i shutdown nadmiarowych nodów

**Konfiguracja**:
```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: gpu-ondemand
spec:
  template:
    spec:
      requirements:
        - { key: nvidia.com/gpu.product, operator: In, values: [NVIDIA-A100-PCIE-40GB] }
        - { key: karpenter.sh/capacity-type, operator: In, values: [on-demand] }
  limits:
    cpu: 1000
    nvidia.com/gpu: 64                  # globalny limit dla całego pool
  disruption:
    consolidationPolicy: WhenUnderutilized   # consolidacja gdy <50% util
    expireAfter: 720h                        # cycle node co 30 dni
```

## Preventive maintenance dla GPU

GPU mają wyższy MTBF failure niż CPU. Symptomy:
- ECC double-bit errors → silent data corruption (model fail, ale "training nie pada")
- Thermal throttling → degraded performance
- Driver crashes → restart node

**Process**:
1. Monitor DCGM metryki (D5/07/06)
2. Alert na ECC errors lub throttling
3. Cordon + drain GPU node (D3/09)
4. SSH + run NVIDIA diagnostics (`nvidia-smi -i 0 -q`, `nvidia-smi --query-remapped-rows`)
5. Decision: replace lub wymiana całego node
6. Karpenter / CA wstaje nowego

## Image strategy dla AI

NVIDIA NGC (`nvcr.io/nvidia/...`) to gotowe obrazy z CUDA + cuDNN + popularnymi frameworks (PyTorch, TF, NeMo, Triton). 5-10 GB.

**Layered caching**:
```dockerfile
# Stage 1: base z CUDA (rzadko zmienia się — cache hit prawie zawsze)
FROM nvcr.io/nvidia/pytorch:24.01-py3 AS base

# Stage 2: nasze deps
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Stage 3: nasz kod (zmienia się często)
COPY . /app
WORKDIR /app
ENTRYPOINT ["python", "train.py"]
```

**Image pull bottleneck**: 5GB na 100 nodów = 500GB ruchu. Solutions:
- Local registry (Harbor) per region
- Image preloading przez DaemonSet który `crictl pull` na startup nodów
- [Spegel](https://github.com/spegel-org/spegel) — peer-to-peer image distribution w klastrze

## Cost monitoring

```promql
# Per-team GPU cost (assuming $2/h per A100 + label "team")
sum by (team) (
  count by (team) (kube_pod_container_resource_requests{resource="nvidia_com_gpu"})
) * 2 * 24 * 30
# = monthly cost per team
```

Tools:
- **OpenCost** (CNCF) — szczegółowy cost breakdown per pod/namespace/label
- **Kubecost** — komercyjne rozszerzenie OpenCost
- **CAST AI** — AI-driven cost optimization recommendations

## Checklist produkcyjny

- [ ] Dedicated GPU node pool z taints
- [ ] NVIDIA GPU Operator (lub fake dla testów)
- [ ] DCGM Exporter + Prometheus alerts
- [ ] Spot instances dla training (z checkpointing)
- [ ] Karpenter zamiast Cluster Autoscaler (lepsze dla GPU)
- [ ] PriorityClass dla critical inference (D3/07)
- [ ] PDB dla inference deployments (D3/09)
- [ ] Image pre-loading lub Spegel (mitigation 5GB+ obrazów)
- [ ] Kueue dla multi-tenant fair sharing (D5/07/05)
- [ ] OpenCost dla cost visibility
- [ ] MIG strategy: mixed dla heterogenic workloads

## Linki

- [NVIDIA GPU Operator docs](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/)
- [Karpenter GPU NodePools](https://karpenter.sh/docs/concepts/nodepools/)
- [OpenCost](https://www.opencost.io/)
- [AWS spot instance guide for ML](https://aws.amazon.com/blogs/machine-learning/optimizing-costs-for-machine-learning-with-amazon-sagemaker-savings-plans-and-spot-instances/)
