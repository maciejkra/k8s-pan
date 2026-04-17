# 05 — Kueue: job queuing dla AI/ML (przegląd)

> Tylko teoria — Kueue jest obszerny, w 5-dniowym kursie omawiamy koncept i kiedy używać.

## Problem

K8s domyślny scheduler:
- Pod jest **albo Pending** (brak zasobów) **albo Running** (są zasoby)
- Nie ma "kolejki" — Pending pody walczą losowo o zasoby gdy się zwalniają
- Brak fair sharing między teamami / projektami
- Trudne kapacityty management (kto ma priority, kto czeka, ile)

W AI/ML to bolesne:
- Training jobs trwają godziny/dni
- Wiele teamów współdzieli drogie GPU
- Trzeba: "team A ma quota 8 GPU, team B 16, jeśli A nie używa to B może wziąć temporariy"

## Rozwiązanie: Kueue

[Kueue](https://kueue.sigs.k8s.io/) — Kubernetes-natywny job queueing system.

Główne CRD-y:
- **ResourceFlavor** — typ zasobu (np. `nvidia-a100`, `nvidia-h100`, `nvidia-l4`). Mapuje na nodeSelector / tolerations
- **ClusterQueue** — globalna kolejka z quota: "team-platform: 16× a100, 32× l4"
- **LocalQueue** — namespace-local proxy do ClusterQueue: "moja kolejka 'experiments' używa ClusterQueue 'team-platform'"
- **Workload** — auto-tworzony per Job/JobSet — reprezentuje "ten Job czeka w kolejce"

## Flow

```
1. User: kubectl apply -f my-job.yaml          # Job z label "kueue.x-k8s.io/queue-name=experiments"
2. Kueue: tworzy Workload, dodaje do LocalQueue "experiments"
3. LocalQueue forwarduje do ClusterQueue "team-platform"
4. ClusterQueue sprawdza quota — czy team-platform ma jeszcze 4×a100 wolne?
   - TAK → Workload Admitted → Pod startuje
   - NIE → Workload czeka aż inny job się skończy
5. Po skończeniu Joba → quota zwracana, kolejny job z kolejki Admitted
```

## Przykład manifestu

```yaml
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: nvidia-a100
spec:
  nodeLabels:
    nvidia.com/gpu.product: NVIDIA-A100-SXM4-40GB
---
apiVersion: kueue.x-k8s.io/v1beta1
kind: ClusterQueue
metadata:
  name: team-platform
spec:
  namespaceSelector: {}                # wszystkie namespace
  resourceGroups:
    - coveredResources: ["cpu", "memory", "nvidia.com/gpu"]
      flavors:
        - name: "nvidia-a100"
          resources:
            - { name: "cpu",            nominalQuota: 100 }
            - { name: "memory",         nominalQuota: 400Gi }
            - { name: "nvidia.com/gpu", nominalQuota: 16 }
---
apiVersion: kueue.x-k8s.io/v1beta1
kind: LocalQueue
metadata:
  namespace: ml-experiments
  name: experiments
spec:
  clusterQueue: team-platform
---
apiVersion: batch/v1
kind: Job
metadata:
  namespace: ml-experiments
  name: train-llama
  labels:
    kueue.x-k8s.io/queue-name: experiments
spec:
  parallelism: 1
  completions: 1
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: trainer
          image: nvcr.io/nvidia/pytorch:23.10-py3
          resources:
            limits:
              nvidia.com/gpu: 8
              cpu: "32"
              memory: 128Gi
```

## Zaawansowane funkcje Kueue

- **Cohorts** — grupy ClusterQueue dzielące się quota (jeśli team A nie używa, team B borrowuje, ale max do `borrowingLimit`)
- **Preemption** — Workload o wyższym priority wywłaszcza niższe (analogiczne do K8s PriorityClass, ale na poziomie Job)
- **Multi-cluster** — Kueue + MultiKueue dispatchuje do różnych klastrów (np. dev na K3s, prod na EKS)
- **Job framework integrations** — natywne wsparcie dla Job, JobSet, MPIJob, RayJob, PyTorchJob

## Kiedy Kueue?

✅ **Tak**:
- Klaster AI/ML współdzielony przez 2+ teamy
- Drogie GPU które trzeba sprawiedliwie dzielić
- Workloads gdzie czas startu może być opóźniony (training, batch inference) — vs ciężko dla real-time inference

❌ **Nie**:
- Klaster general-purpose (web apps + microservices) — Kueue nie pomoże
- Single-tenant cluster — quota nie ma sensu
- Real-time workloads które nie tolerują delay startu

## Alternatywy

- **Volcano** — CNCF batch scheduler, więcej funkcji niż Kueue (gang scheduling, fair-share), bardziej skomplikowany
- **YuniKorn** — Apache, oryginalnie z Yahoo dla Spark/Flink, podobny zakres
- **K8s ResourceQuota** + **PriorityClass** — built-in, bez kolejki, mniej zaawansowany ale wystarczy dla wielu

## Linki
- [Kueue docs](https://kueue.sigs.k8s.io/)
- [Tutorial: Run a Job](https://kueue.sigs.k8s.io/docs/tasks/run/jobs/)
- [Multi-cluster Kueue](https://kueue.sigs.k8s.io/docs/concepts/multikueue/)
