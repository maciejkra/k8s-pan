# 03 — ResourceQuota i LimitRange

## Cel
Wymusić limity zasobów na poziomie namespace (`ResourceQuota`) i ustawić **defaulty** dla Pod-ów które nie wyspecyfikowały requests/limits (`LimitRange`).

## Kontekst
Bez kontroli — ktoś z teamu A może wziąć cały klaster przez `replicas: 1000`. Trzy mechanizmy:

1. **ResourceQuota** — limit per **namespace**: max suma CPU/memory/Pod count/PVC count
2. **LimitRange** — defaulty + min/max **per Pod/container** w namespace (auto-injection requests/limits jeśli brak)
3. **PriorityClass** (D3/07) — kto ma pierwszeństwo gdy klaster pełny

Typowy setup produkcyjny:
- ClusterRole `quota-admin` przypisany do platform team
- Każdy team-namespace dostaje ResourceQuota wg swojego budżetu
- LimitRange wymusza `requests` żeby aplikacje bez ustawień nie krzywiły schedulingu

## Prereqs
- K3d/Kind cluster

## Zadanie

1. Stwórz namespace + zaaplikuj ResourceQuota i LimitRange:
   ```bash
   kubectl create ns test-1
   kubectl apply -f ns-quota.yaml
   ```

2. Wdroż deployment **bez explicit requests** — LimitRange wstrzyknie defaulty:
   ```bash
   kubectl apply -f deployment.yaml -n test-1
   kubectl describe deploy -n test-1 nginx-readiness
   # Container resources: będą wartości z LimitRange.spec.limits[].defaultRequest
   ```

3. Skala do 3 replik — sprawdź czy mieści się w quota:
   ```bash
   kubectl scale deployment -n test-1 nginx-readiness --replicas=3
   kubectl -n test-1 describe deploy nginx-readiness
   ```

4. Sprawdź ile quota zostało:
   ```bash
   kubectl describe resourcequota -n test-1
   # Used vs Hard per zasób
   ```

5. Spróbuj przekroczyć quota (np. scale do 100):
   ```bash
   kubectl scale deployment -n test-1 nginx-readiness --replicas=100
   kubectl -n test-1 describe rs $(kubectl -n test-1 get rs -o jsonpath='{.items[0].metadata.name}')
   # Events pokażą "exceeded quota"
   ```

## Pytania kontrolne
1. ResourceQuota vs LimitRange — czemu oba potrzebne?
2. Co się stanie gdy istnieje LimitRange `min: 100m CPU` a Pod prosi o `50m`?
3. Jak ResourceQuota współpracuje z PriorityClass? (Hint: scope przez `scopeSelector`)
4. Quota dla **counts** (max 50 Pod-ów per ns) — kiedy przydatne?

## Linki
- [Resource Quotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/)
- [Limit Ranges](https://kubernetes.io/docs/concepts/policy/limit-range/)
- [Scheduler architecture](https://kubernetes.io/docs/concepts/scheduling-eviction/kube-scheduler/)
- [Scheduler profiles](https://kubernetes.io/docs/reference/scheduling/config/#profiles)
