# Solution — 09_node_maintenance

## Odpowiedzi

### --ignore-daemonsets
DaemonSet po definicji uruchamia **jeden Pod per node**. `kubectl drain` próbowałby ewikuować Pod DaemonSet → DaemonSet kontroler natychmiast tworzy nowy → drain w nieskończonej pętli. Flaga mówi: "ja wiem, te Pody zostają na tym node, to OK".

### minAvailable vs maxUnavailable
- **minAvailable: 50%** — przy 10 replikach: zawsze min. 5 dostępnych. Skala: jak rośnie liczba replik, rośnie też minimum.
- **maxUnavailable: 1** — niezależnie od liczby replik: max 1 niedostępny naraz. Bardziej rygorystyczne dla małych deploymentów (3 repliki + maxUnavailable=1 = nigdy więcej niż jeden down), bardziej liberalne dla dużych (100 replik + maxUnavailable=1 = drain nie skończy się nigdy).

Praktyka: `maxUnavailable: 1` dla bazy danych (StatefulSet 3 nody, jeden down), `minAvailable: 75%` dla web (10 replik, max 2-3 down).

### Drain zablokowany przez PDB
```bash
kubectl drain $NODE ...
# Output: cannot evict pod as it would violate the pod's disruption budget
```

Debug:
```bash
kubectl describe pdb               # current vs desired healthy
kubectl get pods -o wide -l <selector>   # gdzie są inne repliki?
```

Możliwe przyczyny:
- inne repliki same w stanie Pending/CrashLoopBackOff (nie liczą się jako Healthy → PDB nie pozwoli kolejnej ewikcji)
- ReplicaSet ma za mało replik
- topologySpreadConstraints uniemożliwia re-scheduling

Rozwiązania (od najlepszego):
1. Naprawić niezdrowe Pody (root cause)
2. Skalować Deployment +1 replika tymczasowo
3. `kubectl drain --disable-eviction` (skip PDB, tylko awaryjnie!)

### Drain a PriorityClass
Drain nie patrzy na PriorityClass — używa eviction API, które honoruje PDB. PriorityClass działa przy **scheduler preemption**, nie przy administracyjnym drain.

Konsekwencja: nawet `system-cluster-critical` Pody mogą być drainowane (np. kube-dns wymaga PDB żeby nie zniknąć z node'a podczas patchowania).

## Walidacja

```bash
# Z PDB
$ kubectl drain k3d-training-agent-0 --ignore-daemonsets --delete-emptydir-data
node/k3d-training-agent-0 cordoned
evicting pod default/critical-svc-xxx
evicting pod default/critical-svc-yyy
pod/critical-svc-xxx evicted
... (czeka aż 3/4 znowu Ready, potem ewikuuje kolejnego)
node/k3d-training-agent-0 drained

# Bez PDB
$ kubectl drain ... 
# Wszystkie 4 repliki ewikuowane natychmiast — krótkie okno downtime
```

## W produkcji

Pełna sekwencja patchowania flotyły 50 nodów:

```bash
for NODE in $(kubectl get nodes -o name); do
  kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data --grace-period=300
  ssh "$(echo $NODE | cut -d/ -f2)" sudo apt upgrade -y && sudo reboot
  # wait for node Ready
  until kubectl get "$NODE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' | grep -q True; do sleep 5; done
  kubectl uncordon "$NODE"
done
```

W praktyce: cluster-autoscaler / Karpenter / kured (kubernetes reboot daemon) automatyzują to.
