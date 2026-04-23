# Zadanie (wspólne dla 3 podkatalogów)

Każdy podkatalog ma własny README z konkretnymi krokami. To spójny walkthrough łączący wszystkie 3 mechanizmy.

## Część 1 — Node Affinity ([`01_affinity/`](./01_affinity/))

1. Sprawdź labele nodów:
   ```bash
   kubectl get nodes --show-labels | tr ',' '\n' | grep -E 'region|disk|role' | sort -u
   ```

2. Zaaplikuj:
   ```bash
   kubectl apply -f 01_affinity/node-affinity.yaml
   kubectl describe pod node-affinity-demo | tail -15
   # Events: nie było matching node (required disk-type=ssd|nvme)
   ```

3. Dodaj label:
   ```bash
   NODE=$(kubectl get nodes -o name | head -1)
   kubectl label $NODE disk-type=ssd --overwrite
   kubectl get pod node-affinity-demo -o wide
   # Po ~5s: Running na wybranym node
   ```

4. Zaaplikuj podAntiAffinity demo:
   ```bash
   kubectl apply -f 01_affinity/pod-antiaffinity.yaml
   kubectl get pods -l app=ha-db -o wide
   # Każda replika na innym NODE
   ```

## Część 2 — Taints ([`02_taints/`](./02_taints/))

Patrz `02_taints/README.md` — pełny walkthrough.

Quick start:
```bash
NODE=$(kubectl get nodes --selector='!node-role.kubernetes.io/control-plane' -o name | head -1 | cut -d/ -f2)
kubectl taint nodes "$NODE" dedicated=workshop:NoSchedule
kubectl apply -f 02_taints/python-deployment.yaml
# Obserwuj Pending (brak tolerations)
# Odkomentuj tolerations w YAML + re-apply
# Pod teraz się umieszcza
kubectl taint nodes "$NODE" dedicated=workshop:NoSchedule-   # cleanup
```

## Część 3 — Topology Spread ([`03_tsc/`](./03_tsc/))

Wymaga 3+ nodów (K3d `k3d cluster create training --agents 2`, Kind kind.config.yaml z `workers: 2`).

```bash
kubectl apply -f 03_tsc/tsc.pod.yaml
kubectl get pods -l app=tsc-demo -o wide --no-headers | awk '{print $7}' | sort | uniq -c
# Spodziewane: równomierny rozkład po NODE (maxSkew 1)
```

## Pytania (całościowe)

1. Kiedy user wybiera **affinity** vs **taint+toleration**? (Hint: kierunek — Pod push vs Node pull.)
2. **nodeSelector** (stary prosty) → **nodeAffinity** → **topology spread** → **scheduling profiles** (custom scheduler) — sytuacje na każdą.
3. HA Postgres StatefulSet (3 repliki) — które mechanizmy kombinujesz i dlaczego?
4. GPU node pool — pełny setup (taint + toleration + nodeSelector/affinity + ewentualnie TSC per zone).
5. **Bonus**: Karpenter/Cluster Autoscaler — jak scheduling rules wpływają na ich decyzje (np. spot fallback)?
