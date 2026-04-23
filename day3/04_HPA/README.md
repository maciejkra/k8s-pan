# 04 — Horizontal Pod Autoscaler (HPA)

## Cel
Skalować automatycznie Deployment na podstawie zużycia CPU. Zaobserwować scale-up pod obciążeniem i scale-down po zatrzymaniu. Zrozumieć `spec.behavior` (policies dla scaleUp/scaleDown).

## Kontekst
**HPA** = kontroler zwiększający/zmniejszający `replicas` Deployment (lub StatefulSet) na podstawie metryk:
- **CPU/memory** (przez Metrics Server — D3/03)
- **Custom metrics** (przez Prometheus Adapter — D5/02)
- **External metrics** (np. SQS queue length — wymaga adapter)

### Algorytm

```
desiredReplicas = ceil(currentReplicas × currentMetric / targetMetric)
```

Przykład: 3 Pody × 80% avg CPU, target 50% → `ceil(3 × 80/50) = 5` replik.

### `spec.behavior` — kontrola tempa

Domyślnie:
- **scaleUp**: 0s stabilization, policies +100% albo +4 Pody co 15s (szybki burst).
- **scaleDown**: 300s stabilization (5min), policies -100% co 15s (ale czeka 5min po ostatnim peaku).

Dlaczego asymmetric? Scale-up = "app ma się nie wywrócić, lepiej mieć za dużo". Scale-down = "poczekajmy aż ruch na pewno się skończył, nie flapujmy".

Tu pokazujemy customowe:
- `scaleUp`: 0s window + policies +100% albo +4 co 30s → agresywny burst
- `scaleDown`: 60s window → szybszy scale-down niż default (dla nauki, w produkcji zostaw 5min)

## VPA vs Cluster Autoscaler

- **VPA (Vertical Pod Autoscaler)** — zmienia **resources** (requests/limits) zamiast `replicas`. Osobny komponent, wymaga instalacji.
- **Cluster Autoscaler / Karpenter** — dodaje/usuwa **nody** (GPU D5/04 + slajd prezentacji "GPU production practices").

## Prereqs
- K3s / Kind / K3d cluster
- **Metrics Server** (D3/03) musi działać (`kubectl top pods` zwraca wartości)

## Pliki

- `hpa/hpa-dep.yaml` — Deployment `php-apache` (demo app) + Service
- `hpa/hpa.yaml` — HPA z target CPU 50% + customowy `behavior`

## Zadanie

Patrz [`task.md`](./task.md).

## Linki
- [HPA walkthrough](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/)
- [HPA algorithm details](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/#algorithm-details)
- [HPA behavior (policies)](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/#configurable-scaling-behavior)
- [Metrics Server](https://github.com/kubernetes-sigs/metrics-server)
