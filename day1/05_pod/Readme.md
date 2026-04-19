# 05 — Pod (najmniejsza jednostka K8s)

## Cel
Stworzyć pierwszy Pod, sprawdzić jego stan, wejść do kontenera, port-forward do localhosta.

## Kontekst
**Pod** = jeden lub więcej kontenerów dzielących sieć i storage. To **najmniejsza** jednostka schedulowalna w K8s. Nigdy nie tworzysz Pod-a samego (bez kontrolera) w produkcji — używaj Deployment/StatefulSet/Job.

W tym ćwiczeniu tworzymy "goły" Pod tylko dla nauki — żeby zrozumieć podstawowe operacje przed wprowadzeniem ReplicaSet (D1/10) i Deployment (D1/11).

## Prereqs
- K3d/Kind cluster

## Zadanie

1. Stwórz Pod:
   ```bash
   kubectl apply -f pod.yaml
   ```

2. Sprawdź:
   ```bash
   kubectl get pods
   kubectl get pods -A                           # wszystkie namespace
   kubectl get all                               # pods, services, deployments, ...
   kubectl get pod -A --selector="app=myapp"     # filtrowanie po label
   ```

3. Wejdź do kontenera:
   ```bash
   kubectl exec -ti myapp-pod -- curl localhost
   ```

4. Logi:
   ```bash
   kubectl logs myapp-pod
   kubectl logs -f myapp-pod                     # follow (stream)
   kubectl logs --previous myapp-pod             # logi z poprzedniej instancji (jeśli był restart)
   ```

5. Port-forward (lokalny dostęp do Pod-a bez Service):
   ```bash
   kubectl port-forward pod/myapp-pod 8080:80
   # W innym terminalu:
   curl localhost:8080
   ```

## Pytania kontrolne
1. Co się stanie gdy usunę Pod (`kubectl delete pod`)? Czy się odtworzy?
2. Czemu Pod (a nie kontener) jest jednostką schedulingu?
3. `port-forward` — przez co idzie ruch? (Hint: TCP tunnel przez API server)
4. Pod ma dwa kontenery — jak wybrać do którego idzie `kubectl logs`?

## Linki
- [Pods](https://kubernetes.io/docs/concepts/workloads/pods/)
- [Pod lifecycle](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/)
