# Solution — 02_limitrange

## Odpowiedzi

### Pod z requests=100m, LimitRange min=200m

**Pod zostanie odrzucony** przez admission controller:
```
Error: minimum cpu usage per Container is 200m, but request is 100m
```

Ważne: admission sprawdza **po** merge z defaultami. Jeśli Pod ma explicit `requests=100m` (user zadeklarował), to wygrywa z default z LimitRange, ale nadal musi spełniać `min`. Minimum jest zawsze egzekwowane, niezależnie od tego skąd wartość przyszła.

### LimitRange dla PVC storage

Tak, LimitRange obsługuje `type: PersistentVolumeClaim`:

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: storage-constraint
spec:
  limits:
  - type: PersistentVolumeClaim
    min:
      storage: 1Gi
    max:
      storage: 100Gi
```

Brak `default`/`defaultRequest` dla PVC (użytkownik zawsze musi podać `requests.storage`). Użycie: zapobieganie "hobby PVC" (5Gi dla każdej aplikacji, gdy faktycznie potrzeba 100Mi) i "enterprise PVC" (10Ti dla dev).

### `type: Pod` vs `type: Container`

- **`type: Container`** — sprawdzane per kontener. Pod z 3 kontenerami × `max.cpu: 1` = Pod może mieć do 3 CPU (każdy kontener max 1).
- **`type: Pod`** — sumę. `max.cpu: 1` dla type Pod = wszystkie kontenery razem nie mogą przekroczyć 1 CPU.

Pragmatyka:
- **Container** — default w większości use cases. Kontenery same siebie ograniczają.
- **Pod** — gdy chcesz kontrolować koszty (każdy Pod max X CPU, independentnie od liczby kontenerów).

### LimitRange po istniejących Pod-ach

**NIE zmieni** istniejących Pod-ów — są już created. Admission działa tylko przy create/update. Trzeba:
1. Delete+recreate Pody (Deployment rollout).
2. Albo patch Pod (jeśli pole jest mutowalne — `requests`/`limits` są).

Podobnie: usunięcie LimitRange nie zmienia istniejących Pod-ów.

### Wiele LimitRange w jednym NS

Tak. Wszystkie są egzekwowane jednocześnie → Pod musi spełniać **każdy**. Przykład:
- LimitRange A: `max.cpu: 2` per container
- LimitRange B: `max.cpu: 3` per Pod (suma)
- Pod z 1 kontenerem 1500m CPU → OK (≤2 per container, ≤3 per Pod)
- Pod z 3 kontenerami × 800m = 2400m → **fail** (≤2 per container OK, ale ≤3 per Pod fail)

Jeśli wiele LimitRange dają sprzeczne `default` → losowy wybór (niedeterministyczne!). W praktyce: ogranicz do 1 LimitRange per NS, albo oddzielnie per type.

## Walidacja

```bash
kubectl create ns ns-limit
kubectl apply -f limitrange.yaml -n ns-limit
kubectl apply -f pod.yaml -n ns-limit
sleep 3

kubectl get pod myapp-limitrange -n ns-limit -o jsonpath='{.spec.containers[0].resources}' | jq
# {
#   "limits": { "cpu": "500m", "memory": "128Mi" },
#   "requests": { "cpu": "500m", "memory": "128Mi" }
# }

# Oczekiwany reject
kubectl run too-big -n ns-limit --image=nginx:1.27-alpine \
  --overrides='{"spec":{"containers":[{"name":"too-big","image":"nginx:1.27-alpine","resources":{"limits":{"cpu":"2"}}}]}}'
# Error: maximum cpu usage per Container is 1, but limit is 2
```

## Troubleshooting

### LimitRange istnieje, ale Pod bez requests tworzony z BestEffort

Sprawdź namespace — LimitRange jest **per-NS**. Pod w `default` NS nie dostaje `ns-limit` LimitRange.

```bash
kubectl get limitrange -A
```

### "limits != requests" mimo że LimitRange ma equal defaults

LimitRange robi `requests = defaultRequest`, `limits = default`. Jeśli `defaultRequest ≠ default` — Pod będzie Burstable, nie Guaranteed. Sprawdź LimitRange spec.

### PodSecurityAdmission konflikt

W NS z `enforce: restricted` (D4/02) Pod bez `securityContext` jest odrzucany. LimitRange NIE pomoże — security to osobna admission. Potrzebny pełen securityContext.

## Cross-link

- D3/02/01 (QoS classes) — LimitRange wymusza requests → mniej BestEffort Pod-ów
- D3/02/03 (ResourceQuota) — agregacja; razem z LimitRange tworzą parę
- D4/02 (Pod Security Admission) — inna warstwa admission
- D4/03 (ValidatingAdmissionPolicy) — CEL-based alternatywa dla LimitRange gdy potrzebujesz customowych reguł
