# 10 — ReplicaSet

## Cel
Zrozumieć czym jest ReplicaSet (predecessor Deployment), jak utrzymuje pożądaną liczbę Podów i co znaczy `--cascade=false` przy delete.

## Kontekst
**ReplicaSet** to kontroler dbający o "zawsze N replik tego Pod-a żyje". Jeśli ktoś usunie Pod — ReplicaSet tworzy nowy. Jeśli Pod się rozkraczy — to samo.

W praktyce **nie używamy ReplicaSet bezpośrednio** — Deployment (D1/11) tworzy ReplicaSet pod spodem i dodaje strategie wdrożeń (rolling update, recreate). ReplicaSet jest dobrym ćwiczeniem do zrozumienia "controller pattern" w K8s.

## Prereqs
- K3d/Kind cluster

## Zadanie

1. Sprawdź stan początkowy:
   ```bash
   kubectl get pod
   ```

2. Zaaplikuj ReplicaSet:
   ```bash
   kubectl apply -f replica-set.yaml
   kubectl get all
   ```

3. Stwórz Pod z **tym samym labelem** co ReplicaSet selector — co się stanie?
   ```bash
   kubectl apply -f pod.yaml
   kubectl get pod
   kubectl get events
   # ReplicaSet "adopts" istniejący pasujący Pod (lub usuwa nadmiarowy)
   ```

4. Usuń Pod z ReplicaSet:
   ```bash
   kubectl delete pod myapp-pod
   kubectl get pod
   # Nowy Pod natychmiast zostanie utworzony
   ```

5. Skaluj:
   ```bash
   kubectl scale rs replicate-my-app --replicas=3
   kubectl get all
   ```

6. Usuń ReplicaSet (cascade — usuwa też Pody):
   ```bash
   kubectl delete rs replicate-my-app
   kubectl get all
   ```

7. Cascade=false — usuń ReplicaSet ale **zostaw Pody**:
   ```bash
   kubectl apply -f replica-set.yaml
   kubectl describe rs replicate-my-app
   kubectl delete rs replicate-my-app --cascade=false
   kubectl get rs       # nie ma
   kubectl get pod      # Pody zostały
   ```

## Pytania kontrolne
1. ReplicaSet vs ReplicationController (legacy)?
2. Czy mogę zaktualizować image w ReplicaSet i istniejące Pody dostaną nowy image? (Hint: nie — to robi Deployment)
3. Kiedy `--cascade=false` jest przydatne?
4. Co się stanie jeśli ReplicaSet ma `replicas: 5` ale tylko 3 nody mają miejsce?

## Linki
- [ReplicaSet docs](https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/)
