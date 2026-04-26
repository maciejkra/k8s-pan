# Zadanie — MIG partitioning

## Część 0 — Patch capacity nodów (wymagane dla fake-gpu-operator)

`fake-gpu-operator` **nie eksponuje** `nvidia.com/mig-*` jako Kubernetes extended resource — `mig-faker` tylko ustawia annotacje (`run.ai/mig-mapping`) które konsumuje Run:AI scheduler. W realnym klastrze NVIDIA GPU Operator partycjonuje GPU i kubelet rejestruje capacity automatycznie. Tu **ręcznie patchujemy** capacity żeby pokazać scheduling:

```bash
NODE=$(kubectl get nodes -l run.ai/simulated-gpu-node-pool=default -o name | head -1 | cut -d/ -f2)
kubectl patch node $NODE --subresource=status --type=merge \
  --patch='{"status":{"capacity":{"nvidia.com/mig-1g.5gb":"7","nvidia.com/mig-3g.20gb":"2"}}}'
```

> **Pedagogicznie:** liczby 7 i 2 odpowiadają geometrii MIG na A100 40GB:
> - 7× `1g.5gb` = pełne wykorzystanie wszystkich 7 SM slices po 5GB
> - 2× `3g.20gb` = dwa większe instances (każdy 3/7 SM, 20GB)

## Część 1 — Sprawdź capacity

```bash
kubectl describe node $NODE | grep -E "mig-1g|mig-3g"
# Spodziewane:
#   nvidia.com/mig-1g.5gb:   7
#   nvidia.com/mig-3g.20gb:  2
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
