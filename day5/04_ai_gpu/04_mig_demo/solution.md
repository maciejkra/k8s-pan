# Solution — 04_mig_demo

## Odpowiedzi

### MIG: statyczny vs dynamiczny
**Statyczny per node** — MIG geometrię (które profile są aktywne) ustawia się przez `nvidia-smi mig` lub MIG manager. Zmiana wymaga:
1. Drain wszystkich GPU workloads na node
2. Reconfigure MIG (`nvidia-smi mig -dgi -i 0 && nvidia-smi mig -cgi 19 -C`)
3. Restart device-plugin (refreshuje device list)

NVIDIA GPU Operator z **GFD** + **mig-manager** automatyzuje to przez label `nvidia.com/mig.config=all-1g.5gb` na node — manager wykonuje powyższy procces.

W K8s nie ma "in-flight MIG resize" — instance type jest dyskretny.

### Strategy: single vs mixed
- **single**: każdy node ma **jeden** typ MIG profile (np. wszystko 1g.5gb). Resource label: `nvidia.com/gpu` (siedem instances udaje 7× GPU). Prostsze do schedulowania, mniej elastyczne.
- **mixed**: node może mieć **różne** typy. Resource labels: `nvidia.com/mig-1g.5gb`, `nvidia.com/mig-3g.20gb` itd. Aplikacje proszą o konkretny profile.

W produkcji większe firmy używają `mixed` (różne workloads — inference, fine-tune, training — chcą różnych rozmiarów). Mniejsze: `single` (jednolite klastry).

### Brak żądanego profile
Pod Pending z `Insufficient nvidia.com/mig-3g.40gb`. Auto-scaling node pool (cluster-autoscaler / Karpenter) **nie pomoże** chyba że node template ma ten profile pre-konfigurowany. MIG reconfig nie jest automatyczny.

Mitigation: zdefiniować dedicated node pool per profile.

### Monitoring MIG
DCGM exporter raportuje metryki **per MIG instance**:
- `DCGM_FI_DEV_GPU_UTIL{gpu="0",mig="3g.20gb-0"}`
- `DCGM_FI_DEV_FB_USED{gpu="0",mig="3g.20gb-0"}` — memory used

Grafana dashboard ID **12239** (NVIDIA DCGM Exporter Dashboard) pokazuje per-instance widoki.

## Walidacja

```bash
# Wszystkie 7×1g.5gb instances zajęte (mamy tylko 3 Pody w demo, ale np. produkcja)
kubectl get pods -l mig-profile=1g.5gb -o wide

# Allocated resources widać per profile
kubectl describe node $NODE | grep -A 12 "Allocated resources"
# Allocated resources:
#   nvidia.com/mig-1g.5gb:    3  7
#   nvidia.com/mig-3g.20gb:   1  2
```

## Practical wisdom

| Workload type | Rekomendowany profile |
|---|---|
| Inference małych modeli (BERT-base, ResNet-50) | 1g.5gb / 1g.10gb |
| Inference dużych modeli (Llama 7B int8) | 2g.20gb / 3g.20gb |
| Fine-tuning małych modeli | 3g.40gb / 4g.40gb |
| Training od zera, multi-node | 7g.80gb (cały GPU, MIG disabled) |
| Vector DB inference | 1g.10gb (memory-bound) |
