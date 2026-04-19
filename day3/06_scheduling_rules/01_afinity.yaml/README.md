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
- **preferredDuringSchedulingIgnoredDuringExecution** — soft preference z wagą (weight)

Use cases:
- `nodeAffinity: required` — workload musi na nodzie z SSD (label `disk=ssd`)
- `podAntiAffinity: required` — dwie repliki bazy **nigdy** na tym samym nodzie
- `podAffinity: preferred` — web i cache chętnie razem (network locality)

## Prereqs
- K3d/Kind cluster z min. 2 node'ami

## Zadanie

1. Zaaplikuj Pod z nodeAffinity (required + preferred):
   ```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: with-node-affinity
   spec:
     affinity:
       nodeAffinity:
         requiredDuringSchedulingIgnoredDuringExecution:
           nodeSelectorTerms:
             - matchExpressions:
                 - key: kubernetes.io/e2e-az-name
                   operator: In
                   values: [e2e-az1, e2e-az2]
         preferredDuringSchedulingIgnoredDuringExecution:
           - weight: 1
             preference:
               matchExpressions:
                 - key: another-node-label-key
                   operator: In
                   values: [another-node-label-value]
     containers:
       - name: with-node-affinity
         image: registry.k8s.io/pause:3.9
   ```

2. Bez etykiety `kubernetes.io/e2e-az-name` na żadnym node → Pod Pending (`required`).
   Dodaj label na node i zobacz jak Pod się scheduluje:
   ```bash
   kubectl label nodes <nodename> kubernetes.io/e2e-az-name=e2e-az1
   kubectl describe pod with-node-affinity | tail -20
   ```

3. **Bonus — podAntiAffinity** (nigdy dwie repliki na jednym node):
   ```yaml
   affinity:
     podAntiAffinity:
       requiredDuringSchedulingIgnoredDuringExecution:
         - labelSelector:
             matchLabels: { app: my-app }
           topologyKey: kubernetes.io/hostname
   ```

## Pytania kontrolne
1. `nodeSelector` (D2 staticznie) vs `nodeAffinity` — dlaczego affinity jest bardziej elastyczny?
2. `IgnoredDuringExecution` — co się stanie gdy label znika z node w runtime?
3. `podAffinity` vs `TopologySpreadConstraints` (D3/06/03) — kiedy które?
4. `hard` (required) vs `soft` (preferred) — kiedy ryzykować Pending (required)?

## Linki
- [Assign Pods to Nodes (Affinity)](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/)
- [Inter-pod affinity and anti-affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#inter-pod-affinity-and-anti-affinity)
