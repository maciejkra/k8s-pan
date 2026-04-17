# Solution — 07_pod_priority

## Spodziewane events

```
LAST SEEN   TYPE     REASON              OBJECT                          MESSAGE
30s         Normal   Preempted           pod/batch-workers-xxx-yyy        Preempted by pod default/critical-payment on node k3d-training-agent-1
30s         Normal   Killing             pod/batch-workers-xxx-yyy        Stopping container worker
28s         Normal   Scheduled           pod/critical-payment             Successfully assigned default/critical-payment to k3d-training-agent-1
```

## Odpowiedzi

### globalDefault: true
Pody utworzone bez `priorityClassName` dostają tę klasę automatycznie. **W jednym klastrze może być tylko jedna** klasa z `globalDefault: true` (kube-apiserver waliduje). Typowo: nie ustawiać — bezpieczniej żeby twórca Poda świadomie wybrał priorytet.

### preemptionPolicy: Never
Pod będzie miał wysoki priorytet (lepsze miejsce w kolejce schedulera), **ale** nie wywłaszczy nikogo. Użycie:
- workload "ważny ale nie pilny" — czeka aż zwolni się miejsce, nie zabija batchy
- environment dev/staging — nie chcemy chaos z wywłaszczaniem

### Priority vs QoS
Niezależne wymiary:
- **Priority** (PriorityClass) — kolejność przy schedulingu i wywłaszczaniu
- **QoS** (Guaranteed/Burstable/BestEffort) — kolejność przy node pressure (kubelet wybiera kogo OOM-killnąć przy braku pamięci)

Pod może być Guaranteed + low priority (np. dev workload z dobrze ustawionymi requests=limits ale niskim priorytetem) lub BestEffort + high priority (raczej rzadko).

### Preemption a PDB
Od K8s 1.27 (alpha) → 1.28 (beta) preemption respektuje PodDisruptionBudget przez `preemptionPolicy`. Wcześniej PDB był ignorowany przy preemption (tylko przy `kubectl drain`).

W praktyce: jeśli high-priority Pod nie znajdzie ofiary nie naruszającej PDB, scheduler może odmówić preemption i Pod pozostanie Pending.

## Walidacja

```bash
kubectl describe pod critical-payment | grep -A 5 "Events:"
# Spodziewane: Successfully assigned ... + (jeśli klaster był zatłoczony) wcześniejszy preemption events innych Podów

kubectl get pods -l tier=batch
# Część replik powinna być Pending (nie ma już miejsca po preemption)
```
