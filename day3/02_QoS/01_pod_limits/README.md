# 01 — Pod resource requests i limits (QoS classes)

## Cel
Zrozumieć różnicę `requests` vs `limits`, klasy QoS (Guaranteed, Burstable, BestEffort) i jak K8s decyduje kogo OOM-killnąć przy node pressure.

## Kontekst
Każdy kontener może deklarować:
- **`requests`** — gwarantowane minimum. Scheduler bierze pod uwagę przy wyborze node.
- **`limits`** — twardy max. Aplikacja przekraczająca = throttling (CPU) lub OOM-killed (memory).

K8s przypisuje Pod do **QoS class**:

| QoS | Warunek | Co znaczy |
|---|---|---|
| **Guaranteed** | `requests == limits` dla wszystkich kontenerów (CPU + memory) | Najwyższy priorytet, zabijany ostatni |
| **Burstable** | `requests < limits` lub tylko jedno ustawione | Średni — zabijany przed Guaranteed |
| **BestEffort** | brak `requests` i `limits` | Najniższy — zabijany pierwszy przy node pressure |

W produkcji: **Guaranteed dla critical** (DB, payment), **Burstable dla większości aplikacji** (typowy web), **BestEffort tylko batch/dev**.

## Prereqs
- K3s / Kind / K3d cluster

## Pliki

- `pod-guaranteed.yaml` — requests=limits (100m CPU, 200Mi RAM)
- `pod-burstable.yaml` — requests<limits (50m-200m CPU, 100-400Mi RAM)
- `pod-besteffort.yaml` — brak resources w ogóle

## Zadanie

Patrz [`task.md`](./task.md).

## Linki
- [Configure QoS for Pods](https://kubernetes.io/docs/tasks/configure-pod-container/quality-service-pod/)
- [Resource requests and limits](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Best practices: requests and limits (Google)](https://cloud.google.com/blog/products/containers-kubernetes/kubernetes-best-practices-resource-requests-and-limits)
- [How to Blow up a K8s Cluster (Felix Hoffmann talk)](https://www.youtube.com/watch?v=rjSWVeAvb24)
