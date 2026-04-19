# 02 — LimitRange (defaulty + min/max per Pod)

## Cel
Wymusić w namespace defaultowe `requests`/`limits` dla Pod-ów które ich nie wyspecyfikowały. Ustawić min/max.

## Kontekst
**LimitRange** = policy admission control działający per namespace:
- **default** — gdy Pod nie ma `requests`/`limits`, LimitRange wstrzyknie te wartości
- **defaultRequest** — gdy Pod ma `limits` ale nie `requests`
- **min/max** — twardy zakres dopuszczalnych wartości

Bez LimitRange wszystkie Pody bez ustawień są BestEffort (D3/02/01) → ryzyko że zalewają klaster i destabilizują workload Guaranteed.

LimitRange dotyczy **per-Pod / per-Container**, ResourceQuota (D3/02/03) — agregacji w namespace.

## Prereqs
- K3d/Kind cluster

## Zadanie

1. Stwórz namespace + LimitRange:
   ```bash
   kubectl create ns ns-limit
   kubectl apply -f limitrange.yaml -n ns-limit
   kubectl describe limitrange cpu-resource-constraint -n ns-limit
   ```

2. Wdroż Pod **bez** explicit `requests`/`limits`:
   ```bash
   kubectl apply -f pod.yaml -n ns-limit
   ```

3. Sprawdź czy LimitRange wstrzyknął defaulty:
   ```bash
   kubectl get pod -n ns-limit -o jsonpath='{.items[0].spec.containers[0].resources}'
   # Spodziewane: defaultRequest i default values z LimitRange
   ```

4. Spróbuj wdrożyć Pod **przekraczający** max:
   ```bash
   kubectl run too-big -n ns-limit --image=nginx --requests=cpu=10 --limits=cpu=20
   # Spodziewane: error "maximum cpu usage per Container is X"
   ```

## Pytania kontrolne
1. Pod **z** explicit `requests` = `100m` ale LimitRange `min: 200m` — co się stanie?
2. LimitRange dla `pvc.storage` — kiedy używać?
3. LimitRange dla `pod` (sumę kontenerów) vs `container` (per-container) — kiedy które?
4. Co jeśli LimitRange jest dodany **po** istniejących Pod-ach? Zostaną zmodyfikowane?

## Linki
- [Limit Ranges](https://kubernetes.io/docs/concepts/policy/limit-range/)
- [Configure default CPU](https://kubernetes.io/docs/tasks/administer-cluster/manage-resources/cpu-default-namespace/)
