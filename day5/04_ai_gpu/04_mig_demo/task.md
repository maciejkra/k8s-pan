# Zadanie — MIG partitioning

## Część 1 — Sprawdź capacity

```bash
kubectl get nodes -o jsonpath='{.items[*].status.capacity}' | tr ',' '\n' | grep mig
# Spodziewane (zgodnie z topology.yaml):
# nvidia.com/mig-1g.5gb: 7
# nvidia.com/mig-3g.20gb: 2
```

## Część 2 — Deploy 3× 1g.5gb Pody

```bash
kubectl apply -f mig-1g-pods.yaml
kubectl wait --for=condition=ready pod -l mig-profile=1g.5gb --timeout=30s
kubectl get pods -l mig-profile=1g.5gb -o wide
```

## Część 3 — Deploy 1× 3g.20gb Pod

```bash
kubectl apply -f mig-3g-pod.yaml
kubectl wait --for=condition=ready pod/training-medium --timeout=30s
```

## Część 4 — Sprawdź alokację

```bash
NODE=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o name | head -1 | cut -d/ -f2)
kubectl describe node $NODE | grep -A 15 "Allocated resources" | head -20
```

Oczekiwane:
```
nvidia.com/mig-1g.5gb      3   7       # 3/7 alokowane
nvidia.com/mig-3g.20gb     1   2       # 1/2 alokowane
```

## Część 5 — Próba przekroczenia limitu

Scale do 10 Pod-ów 1g.5gb — max 7, więc 3 powinny być Pending:

```bash
for i in $(seq 4 10); do
  sed "s/inference-small-1/inference-small-$i/" mig-1g-pods.yaml | \
    head -12 | kubectl apply -f -
done
kubectl get pods -l mig-profile=1g.5gb
```

## Część 6 — Cleanup

```bash
kubectl delete pod -l mig-demo=true
```

## Pytania

Patrz `README.md` sekcja "Pytania kontrolne".
