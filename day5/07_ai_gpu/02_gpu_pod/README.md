# 02 — Pod z 1× GPU

## Cel
Wdrożyć Pod żądający 1 GPU, zaobserwować scheduling decision i jak Allocatable spada.

## Zadanie

1. Wdroż:
   ```bash
   kubectl apply -f pod.yaml
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
   #   nvidia.com/gpu  1  4
   ```

4. Wdroż 4 dodatkowe Pody:
   ```bash
   for i in {1..4}; do
     sed "s/gpu-workload/gpu-workload-$i/" pod.yaml | kubectl apply -f -
   done
   kubectl get pods
   ```

5. 5-ty Pod nie zmieści się (4 GPU per node × 2 nody = 8 GPU; 1 + 4 = 5; dwie repliki zmieszczą się na drugim node, ale jeśli zostały tylko 3 — Pending):
   Sprawdź `kubectl describe pod gpu-workload-X | grep -A 5 Events:` jeśli któryś jest Pending.

6. Sprzątnij:
   ```bash
   kubectl delete pod -l app=gpu-test
   ```

## Pytania kontrolne
1. Czemu `requests` i `limits` MUSZĄ być takie same dla `nvidia.com/gpu`?
2. Co się stanie jeśli zażądasz `nvidia.com/gpu: 8` (więcej niż jeden node ma)?
3. Jak rozprasować GPU workload równomiernie po nodach? (Hint: topologySpreadConstraints)
