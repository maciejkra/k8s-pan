# Solution — 06_scheduling_rules

## Odpowiedzi

### Affinity vs Taint+Toleration (kierunek kontroli)

| | Node Affinity | Taint + Toleration |
|---|---|---|
| Kto deklaruje | **Pod** — "chcę być tutaj" | **Node** — "nie chcę was tu, chyba że macie zgodę" |
| Default | nic; bez affinity Pod może pójść gdziekolwiek | nic; bez taint node akceptuje wszystko |
| Typowe użycie | dev chce być w `zone=eu-central` dla latency | infra admin rezerwuje GPU node tylko dla GPU workloadów |
| Kombinacja | komplementarna — razem gwarantują "tylko Pody X na nodach Y" |

Zasada: affinity dla "chcę", taint dla "nie pozwalam". GPU pool: taint (blokuj wszystkich) + nodeSelector GPU (kieruj GPU workload).

### Od nodeSelector do custom scheduler

- `nodeSelector: { gpu: "true" }` — najprostsze, tylko equality match. OK dla prototypów.
- `nodeAffinity` (`In`, `NotIn`, `Exists`, `Gt`, `Lt`) — bardziej elastyczny. Produkcja default.
- `topologySpreadConstraints` — rozkład replik (HA). Dla Deployment z replicas≥2.
- **Scheduler profiles** (K8s 1.19+) — własny scheduler z customową logiką (np. GPU-aware bin-packing). Tylko dla bardzo złożonych przypadków (cloud providers, HPC).

### HA Postgres StatefulSet (3 repliki)

```yaml
spec:
  template:
    spec:
      affinity:
        # Anti-affinity: nie 2 repliki na tym samym nodzie (hostname)
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector: { matchLabels: { app: postgres } }
              topologyKey: kubernetes.io/hostname
      # TSC: rozrzut po zone dla multi-AZ klastra
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector: { matchLabels: { app: postgres } }
      tolerations:
        # Toleration jeśli DB nodes są tainted ("dedicated=database")
        - key: dedicated
          operator: Equal
          value: database
          effect: NoSchedule
      nodeSelector:
        storage: local-ssd
```

Razem: `nodeSelector` → tylko SSD nody, `tolerations` → DB-dedicated, `podAntiAffinity` → każdy Pod inny hostname, `topologySpreadConstraints` → równomiernie między AZ.

### GPU node pool — pełny setup

**Infra admin** (raz):
```bash
# Tainuj GPU node'y
kubectl taint nodes gpu-node-0 gpu-node-1 nvidia.com/gpu=true:NoSchedule

# GPU Feature Discovery (GFD) + NVIDIA Device Plugin (D5/04) labeluje node'y automatycznie:
# nvidia.com/gpu.product=Tesla-A100, nvidia.com/gpu.count=1, itp.
```

**GPU workload** (user):
```yaml
spec:
  tolerations:
    - key: nvidia.com/gpu
      operator: Exists
      effect: NoSchedule
  nodeSelector:
    nvidia.com/gpu.present: "true"
  containers:
    - name: training
      image: nvidia/cuda:12.0-runtime-ubuntu22.04
      resources:
        limits:
          nvidia.com/gpu: 1
```

Dodatkowo: dla **GPU sharing** (D5/04) — MIG profile przez `nvidia.com/mig-1g.10gb: 1` zamiast `nvidia.com/gpu: 1`.

### Karpenter/Cluster Autoscaler interaction

**Cluster Autoscaler** (reaktywny):
1. Pod jest Pending (np. wymaga GPU node).
2. Autoscaler widzi Pending Pod + powody (`FailedScheduling`).
3. Jeśli Pod by się zescheduleował na node z node group X → skaluj X + 1.

Kluczowe: affinity/taints kierują, ale autoscaler musi rozumieć node groups. `nodeSelector` w Pod = autoscaler skaluje group z matching labels. `taints` w node group = autoscaler skaluje tylko jeśli Pod ma toleration.

**Karpenter** (proaktywny):
- Nie ma "node groups" — `NodePool` CRD z `requirements` (instance types, zones, arch).
- Dopasowuje nowy node do wymagań Pending Pod-ów w czasie rzeczywistym (szybszy niż autoscaler, multi-instance-type fallback).
- **Spot fallback**: `NodePool` z `capacity-type: [spot, on-demand]` — Karpenter próbuje spot, fallback do on-demand przy termination.
- Respektuje ALL scheduling rules (affinity, taints, TSC) przy wyborze instance type.

## Walidacja

```bash
# Affinity
kubectl apply -f 01_affinity/node-affinity.yaml
kubectl describe pod node-affinity-demo | grep -A 2 Conditions
# PodScheduled: False (no matching node)
NODE=$(kubectl get nodes -o name | head -1)
kubectl label $NODE disk-type=ssd --overwrite
sleep 3
kubectl get pod node-affinity-demo -o wide
# Running on $NODE

# PodAntiAffinity
kubectl apply -f 01_affinity/pod-antiaffinity.yaml
kubectl get pods -l app=ha-db -o wide --no-headers | awk '{print $7}' | sort -u | wc -l
# == 3 (każda replika na innym node; zakładając 3+ workery)

# Taints
NODE=$(kubectl get nodes --selector='!node-role.kubernetes.io/control-plane' -o name | head -1 | cut -d/ -f2)
kubectl taint nodes "$NODE" dedicated=workshop:NoSchedule
kubectl apply -f 02_taints/python-deployment.yaml
kubectl describe pod -l app=taints-demo | grep -A 5 Events | head -10

# TSC
kubectl apply -f 03_tsc/tsc.pod.yaml
sleep 10
kubectl get pods -l app=tsc-demo -o wide --no-headers | awk '{print $7}' | sort | uniq -c
# Równomierny rozkład
```

## Troubleshooting

### Pod Pending mimo że node ma label

```bash
kubectl describe pod <name> | grep -A 10 Events
```
Typowe:
- Label na node literówka (wrażliwe na wielkość).
- `operator: In` z `values: ["ssd"]` nie matchuje `disk-type=SSD` (capitals).

### Taint nie działa (Pod nadal ląduje)

- Dotknij tylko 1 z N workerów; Pod znajdzie się na innym. Tainuj wszystkie workery.
- K3s/K3d — CP domyślnie **nie** tainted, wszystkie nody akceptują Pody. Nieoczekiwanie Pod ląduje na CP.

### TSC constraint broken na single-node K3d

`topologyKey: kubernetes.io/hostname` na 1 node = wszystkie Pody na jednym hostname = constraint domyślnie narusza. `whenUnsatisfiable: DoNotSchedule` → wszystkie Pending. Użyj `ScheduleAnyway` albo dodaj więcej nodów.

## Cross-link

- D2/09 (DaemonSet) — tolerations dla control-plane
- D3/07 (Priority + preemption) — scheduler może preemptować żeby wpasować Pod (affinity + priority razem)
- D5/04 (GPU) — pełny praktyczny setup z taints/tolerations
- D5/02 (Monitoring) — scheduler metrics (`scheduler_pending_pods`, `scheduler_unschedulable_pods`)
