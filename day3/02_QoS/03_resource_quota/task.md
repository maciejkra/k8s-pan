# Zadanie

## Część 1 — Setup NS z quota + limitrange

```bash
kubectl apply -f ns-quota.yaml
kubectl describe resourcequota team-quota -n test-1
kubectl describe limitrange default-limits -n test-1
```

## Część 2 — Deployment bez explicit resources (LimitRange działa)

```bash
kubectl apply -f deployment.yaml

# Sprawdź co LimitRange wstrzyknął
kubectl get pod -n test-1 -l app=demo -o jsonpath='{.items[0].spec.containers[0].resources}' | jq
# Spodziewane: requests={cpu:100m,memory:128Mi}, limits={cpu:200m,memory:256Mi}
```

## Część 3 — Skala do górnego limitu

```bash
kubectl scale deployment demo -n test-1 --replicas=10
kubectl describe resourcequota team-quota -n test-1
# Used: pods 10/10, requests.cpu 1/2, limits.cpu 2/4, ...
```

## Część 4 — Przekroczenie quota

```bash
kubectl scale deployment demo -n test-1 --replicas=15

# Czekaj chwilę, sprawdź events na ReplicaSet
kubectl describe rs -n test-1 -l app=demo | tail -10
# Events: forbidden: exceeded quota: team-quota, requested: pods=1, used: pods=10, limited: pods=10
```

## Część 5 — Pod poza LimitRange

```bash
kubectl run too-big -n test-1 --image=nginx \
  --overrides='{"spec":{"containers":[{"name":"too-big","image":"nginx","resources":{"limits":{"cpu":"2"}}}]}}'
# Error: maximum cpu usage per Container is 1, but limit is 2
```

## Pytania

1. ResourceQuota vs LimitRange — czemu **oba** potrzebne? Co się stanie jeśli usuniesz LimitRange, zostawisz tylko Quota, i spróbujesz deploy Pod-a bez `resources`?
2. Co się stanie gdy istnieje LimitRange `min.cpu: 100m` a Pod prosi o `50m`? (Pod reject? Admission level?)
3. Jak ResourceQuota współpracuje z PriorityClass (D3/07)? (Hint: `scopeSelector` ogranicza quota do Pod-ów z konkretną klasą priorytetu.)
4. Quota dla **object counts** (max 50 Pod-ów per NS) — kiedy przydatne? Jakie obiekty warto limitować?
5. **Bonus:** ResourceQuota dla `services.loadbalancers` — dlaczego warto w cloud-environments?
