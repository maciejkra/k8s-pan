# Zadanie

## Część 1 — LimitRange wstrzykuje defaulty

1. Stwórz namespace + LimitRange:
   ```bash
   kubectl create ns ns-limit
   kubectl apply -f limitrange.yaml -n ns-limit
   kubectl describe limitrange cpu-resource-constraint -n ns-limit
   ```

2. Wdroż Pod **bez** explicit CPU (tylko memory limit):
   ```bash
   kubectl apply -f pod.yaml -n ns-limit
   ```

3. Zobacz co LimitRange wstrzyknął:
   ```bash
   kubectl get pod myapp-limitrange -n ns-limit -o jsonpath='{.spec.containers[0].resources}' | jq
   # Spodziewane:
   # {
   #   "limits": { "cpu": "500m", "memory": "128Mi" },
   #   "requests": { "cpu": "500m", "memory": "128Mi" }
   # }
   ```

## Część 2 — Próba przekroczenia max

1. Spróbuj wdrożyć Pod powyżej `max.cpu: 1`:
   ```bash
   kubectl run too-big -n ns-limit --image=nginx \
     --overrides='{"spec":{"containers":[{"name":"too-big","image":"nginx","resources":{"limits":{"cpu":"2"}}}]}}'
   # Spodziewany error:
   # maximum cpu usage per Container is 1, but limit is 2
   ```

2. Spróbuj poniżej `min.cpu: 100m`:
   ```bash
   kubectl run too-small -n ns-limit --image=nginx \
     --overrides='{"spec":{"containers":[{"name":"too-small","image":"nginx","resources":{"requests":{"cpu":"50m"}}}]}}'
   # Error: minimum cpu usage per Container is 100m
   ```

## Część 3 — Pod z requests < min

```bash
# requests.cpu: 50m, ale LimitRange min: 100m
kubectl run under-min -n ns-limit --image=nginx \
  --requests=cpu=50m --limits=cpu=500m
# Error: minimum cpu usage per Container is 100m, but request is 50m
```

## Pytania

1. Pod **z** explicit `requests.cpu=100m` ale LimitRange `min.cpu: 200m` — co się stanie? (Hint: admission reject.)
2. LimitRange dla `pvc.storage` — kiedy używać? Czy też ma `min`/`max`/`default`?
3. LimitRange dla `type: Pod` (sumę kontenerów) vs `type: Container` (per-container) — kiedy które?
4. Co jeśli LimitRange jest dodany **po** istniejących Pod-ach? Zostaną zmodyfikowane automatycznie?
5. **Bonus:** możesz mieć **wiele** LimitRange w jednym NS? Jak się łączą?
