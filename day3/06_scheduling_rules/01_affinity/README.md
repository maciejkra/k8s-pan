# 01 — Node Affinity i Pod Affinity/AntiAffinity

## Cel
Kontrolować **gdzie** Pody trafiają za pomocą affinity: preferowane lub wymagane przypisanie do node (lub do sąsiada Pod-a).

## Kontekst
**Affinity** = bardziej elastyczny niż `nodeSelector`. Trzy rodzaje:

1. **nodeAffinity** — Pod preferuje / wymaga konkretnych labelów node
2. **podAffinity** — Pod chce być **blisko** innego Pod-a (np. na tym samym node / zone)
3. **podAntiAffinity** — Pod chce być **daleko** od innego Pod-a (np. dwie repliki na różnych node'ach)

Każde ma dwa tryby:
- **requiredDuringSchedulingIgnoredDuringExecution** — twardy warunek przy schedulingu, po scheduling ignored
- **preferredDuringSchedulingIgnoredDuringExecution** — soft preference z wagą (weight 1-100)

Use cases:
- `nodeAffinity: required` — workload musi na nodzie z SSD (label `disk-type=ssd`)
- `podAntiAffinity: required` — dwie repliki bazy **nigdy** na tym samym nodzie
- `podAffinity: preferred` — web i cache chętnie razem (network locality)

## Prereqs
- K3s / Kind / K3d cluster z min. 2 node'ami

## Pliki

- `node-affinity.yaml` — Pod z `requiredDuring...` (disk-type=ssd) + `preferredDuring...` (region=eu-central)
- `pod-antiaffinity.yaml` — Deployment z 3 replikami, każda na innym hostname (HA pattern)

## Zadanie

Patrz [`../task.md`](../task.md) (wspólny task dla 06 — wszystkie 3 mechanizmy).

Dla tego podkatalogu:

1. Zaaplikuj `node-affinity.yaml` → Pod będzie Pending (żaden node nie ma `disk-type=ssd`):
   ```bash
   kubectl apply -f node-affinity.yaml
   kubectl describe pod node-affinity-demo | tail -20
   # 0/N nodes are available: N node(s) didn't match Pod's node affinity/selector.
   ```

2. Dodaj label na node:
   ```bash
   NODE=$(kubectl get nodes -o name | head -1)
   kubectl label $NODE disk-type=ssd
   # Po kilku sekundach Pod ma się zescheduleowac
   kubectl get pod node-affinity-demo -o wide
   ```

3. Zaaplikuj `pod-antiaffinity.yaml`:
   ```bash
   kubectl apply -f pod-antiaffinity.yaml
   kubectl get pods -l app=ha-db -o wide
   # Każda replika na innym NODE
   ```

4. **Eksperyment**: scale do więcej replik niż nodów:
   ```bash
   kubectl scale deployment ha-db-demo --replicas=5
   # W K3d z 3 node'ami: 2 repliki Pending (required antiAffinity)
   kubectl get pods -l app=ha-db
   ```

## Pytania

1. `nodeSelector` vs `nodeAffinity.required` — co `affinity` dodaje ponad stare? (Hint: `operator: In/NotIn/Exists`.)
2. `IgnoredDuringExecution` — co się stanie gdy label znika z node w runtime?
3. `podAffinity` vs `TopologySpreadConstraints` — kiedy które?
4. `hard` (required) vs `soft` (preferred) — kiedy ryzykować Pending?

## Linki
- [Assign Pods to Nodes (Affinity)](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/)
- [Inter-pod affinity and anti-affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#inter-pod-affinity-and-anti-affinity)
