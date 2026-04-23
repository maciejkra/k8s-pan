# Zadanie

## Część 1 — Stwórz klasy

```bash
kubectl apply -f priorityclasses.yaml
kubectl get priorityclass
# Spodziewane: high (1000), normal (100), batch-low (-10)
```

## Część 2 — Wypełnij klaster low-priority

```bash
kubectl apply -f low-priority-deployment.yaml
sleep 10
kubectl get pods -l tier=batch -o wide
# Część Running, część może Pending jeśli klaster za mały — OK
```

Sprawdź alokację:
```bash
kubectl describe nodes | grep -A 3 "Allocated resources"
# cpu.percent powinno być >70% po wypełnieniu
```

## Część 3 — Wdroż high-priority

```bash
kubectl apply -f high-priority-pod.yaml
```

**Jeśli klaster ma wystarczające luzy** — Pod po prostu wystartuje bez preemption.

**Jeśli klaster jest pełny** — scheduler preemptuje low-priority Pody:
```bash
kubectl get events --sort-by='.lastTimestamp' | grep -iE "preempt|kill" | tail -10
# Spodziewane: "Preempted by pod default/critical-payment"
kubectl describe pod critical-payment | tail -15
# Status: Running
```

## Część 4 — Obserwuj low-priority po preemption

```bash
kubectl get pods -l tier=batch
# Część Pending (wywłaszczone, nie mogą się od razu wrócić)
```

## Część 5 — Cleanup

```bash
kubectl delete -f high-priority-pod.yaml -f low-priority-deployment.yaml -f priorityclasses.yaml
```

## Bonus — non-preempting high priority

Zmień w `priorityclasses.yaml` dla klasy `high`:
```yaml
preemptionPolicy: Never
```

Re-apply + powtórz sekwencję. Co się teraz dzieje gdy klaster jest pełny? (Hint: high-priority Pod Pending, brak preemption — Pod czeka w kolejce, ale lepiej niż low-priority Pody.)
