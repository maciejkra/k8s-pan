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
- K3d/Kind cluster

## Zadanie

1. Wdroż 3 Pody różnych QoS class (manifest w katalogu).

2. Sprawdź klasy:
   ```bash
   kubectl get pods -o json | jq '.items[] | {name: .metadata.name, qos: .status.qosClass}'
   ```

3. Symuluj memory pressure — Pod prosi o więcej niż limit:
   ```bash
   kubectl exec <burstable-pod> -- sh -c "yes 'A' | head -c 1G > /dev/null"
   # OOM jeśli przekroczy limit
   kubectl get pod <burstable-pod>
   # OOMKilled
   ```

4. Sprawdź events:
   ```bash
   kubectl describe pod <killed-pod> | tail -20
   ```

## Pytania kontrolne
1. CPU throttling vs memory OOM — czemu różnica w reakcji?
2. Co jeśli klaster ma 8 CPU a Pod ma `requests.cpu: 16`? (Pending na zawsze)
3. Dlaczego `Guaranteed` dla critical workloads?
4. Co jeśli wszystkie Pody są BestEffort i pojawi się node pressure?

## Linki
- [Configure QoS for Pods](https://kubernetes.io/docs/tasks/configure-pod-container/quality-service-pod/)
- [Resource requests and limits](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Best practices: requests and limits (Google)](https://cloud.google.com/blog/products/containers-kubernetes/kubernetes-best-practices-resource-requests-and-limits)
- [How to Blow up a K8s Cluster (Felix Hoffmann talk)](https://www.youtube.com/watch?v=rjSWVeAvb24)
