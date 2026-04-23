# 02 — Pod z 1× GPU

## Cel
Wdrożyć Pod żądający 1 GPU, zaobserwować scheduling decision i jak Allocatable spada.

## Zadanie

1. Wdroż:
   ```bash
   kubectl apply -f pod.yaml
   kubectl wait --for=condition=ready pod/gpu-workload --timeout=30s
   ```

2. Sprawdź placement:
   ```bash
   kubectl describe pod gpu-workload | grep -E "Node:|nvidia"
   ```

3. Sprawdź zużycie GPU na node:
   ```bash
   NODE=$(kubectl get pod gpu-workload -o jsonpath='{.spec.nodeName}')
   kubectl describe node $NODE | grep -A 8 "Allocated resources"
   # Allocated resources:
   #   nvidia.com/gpu  1  4       # 1/4 allocated na node
   ```

4. Wdroż 4 dodatkowe Pody:
   ```bash
   for i in {1..4}; do
     sed "s/gpu-workload/gpu-workload-$i/" pod.yaml | kubectl apply -f -
   done
   kubectl get pods
   ```

5. Zobacz rozkład:
   ```bash
   # W topology.yaml: 4 GPU per node. Z 2 worker nodami = 8 GPU total.
   # 1 oryginalny + 4 dodatkowe = 5 Podów × 1 GPU = 5 GPU zajęte z 8.
   # Scheduler rozkłada automatycznie między nody.
   kubectl get pods -l app=gpu-test -o wide
   ```

6. **Eksperyment**: dorzuć do 10 Pod-ów. 8 powinno się umieścić, 2 Pending:
   ```bash
   for i in {5..10}; do
     sed "s/gpu-workload/gpu-workload-$i/" pod.yaml | kubectl apply -f -
   done
   kubectl get pods -l app=gpu-test
   # Część Running, część Pending (Insufficient nvidia.com/gpu)
   ```

7. Sprzątnij:
   ```bash
   kubectl delete pod -l app=gpu-test
   ```

## Pytania kontrolne
1. Czemu `requests` i `limits` MUSZĄ być takie same dla `nvidia.com/gpu`? (Hint: extended resources nie wspierają overcommit.)
2. Co się stanie jeśli zażądasz `nvidia.com/gpu: 8` (więcej niż jeden node ma)?
3. Jak rozprasować GPU workload równomiernie po nodach? (Hint: topologySpreadConstraints z D3/06/03.)
4. **Bonus**: MIG z D5/04/04 — jak to zmienia kalkulację "ile GPU dostępne"?
