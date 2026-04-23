# Zadanie

## Część 1 — Setup aplikacji z PDB

```bash
kubectl apply -f app-with-pdb.yaml
kubectl wait --for=condition=ready pod -l app=critical-svc --timeout=60s

kubectl get pods -l app=critical-svc -o wide
kubectl get pdb
# NAME          MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS
# critical-pdb  3               N/A               1
```

## Część 2 — Wybierz node do drain

```bash
NODE=$(kubectl get pods -l app=critical-svc -o wide --no-headers | \
       awk '{print $7}' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
echo "Drain target: $NODE"
```

## Część 3 — Cordon

```bash
kubectl cordon "$NODE"
kubectl get nodes
# "$NODE" ma status: Ready,SchedulingDisabled
```

Sprawdź że istniejące Pody nadal żyją:
```bash
kubectl get pods -l app=critical-svc -o wide
# Wszystkie Running (cordon nie ewikuuje)
```

## Część 4 — Drain z PDB

```bash
kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data
```

Obserwuj:
- Pierwsza ewikcja: scheduler tworzy nowego Poda na innym node
- PDB `minAvailable: 3` — drain czeka aż nowy Pod Ready zanim ewikuuje kolejnego
- Bez PDB — wszystkie 4 leciałyby równocześnie (krótki downtime)

W innym terminalu:
```bash
kubectl get pods -l app=critical-svc -o wide -w
```

## Część 5 — Patching (symulacja)

```bash
# Tu by nastąpił reboot / upgrade
echo "PATCHING $NODE..."
sleep 5
```

## Część 6 — Uncordon

```bash
kubectl uncordon "$NODE"
kubectl get nodes
# "$NODE" z powrotem Ready (bez SchedulingDisabled)
```

Nowe Pody mogą znowu lądować tutaj, ale istniejące nie są re-balansowane automatycznie (rebalancing przez `descheduler` operator).

## Część 7 — Bonus: drain **bez** PDB

```bash
kubectl delete -f app-with-pdb.yaml
kubectl apply -f app-without-pdb.yaml
kubectl wait --for=condition=ready pod -l app=no-pdb-svc --timeout=60s

# Drain jest natychmiastowy — wszystkie 4 repliki ewikuowane równolegle
kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data --force
# --force bo Deployment-owe Pody domyślnie OK, ale bare Pody (bez owner) wymagają
```

Zobacz że wszystkie 4 Pody **znikają jednocześnie** (ryzyko downtime jeśli klient uderza).

## Część 8 — Drain zablokowany przez PDB

```bash
kubectl delete -f app-without-pdb.yaml
kubectl apply -f app-with-pdb.yaml  # minAvailable: 3, replicas: 4
sleep 10

# Celowo złam klaster — zabij 2 Pody z ręki, zostaje 2 running
kubectl delete pod -l app=critical-svc --field-selector status.phase=Running | head -2 | xargs -I{} kubectl delete pod {} 2>/dev/null || true

# Teraz drain — nie może ewikuować, bo PDB wymaga min 3, a tylko 2 są ready
kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data --grace-period=10 --timeout=30s
# Error: cannot evict pod as it would violate the pod's disruption budget
```

## Pytania

1. `--ignore-daemonsets` — dlaczego konieczne? (Hint: DaemonSet Pody zawsze wracają, drain by się zapętlił.)
2. `minAvailable: 50%` vs `maxUnavailable: 1` — kiedy które dla 3-nodowej bazy Redis Cluster? (Hint: dla małych liczb różnica w scale-down.)
3. Drain **zablokowany** przez PDB — jak zdebugować (sekwencja kroków)?
4. Czy drain respektuje PriorityClass (D3/07)? (Hint: nie.)
5. **Bonus**: `kubectl drain --disable-eviction` vs domyślny — kiedy awaryjnie by-passować PDB?
