# 09 — Node maintenance: cordon, drain, PDB

## Cel
Bezpiecznie wyłączyć node z klastra (np. patching kernela, wymiana sprzętu), nie powodując downtime aplikacji.

## Kontekst
Trzy operacje:
- **cordon** — oznacza node jako `Unschedulable`. Nowe Pody nie wylądują na nim, **istniejące zostają**.
- **uncordon** — odwrotność cordon.
- **drain** — cordon + ewikcja wszystkich Podów (z respektem PodDisruptionBudget).

**PodDisruptionBudget (PDB)** — kontrakt: "moja aplikacja może mieć max N Podów niedostępnych jednocześnie" (lub min M dostępnych). `kubectl drain` honoruje PDB — czeka aż ewikcja nie naruszy budżetu.

Typowy flow planowanej obsługi node'a:
```
cordon → drain (z PDB) → patch / reboot → uncordon
```

## Prereqs
- K3d cluster z **min. 2 agentami** (żeby było gdzie ewakuować)

## Zadanie

1. Sprawdź stan node'ów:
   ```bash
   kubectl get nodes
   ```

2. Wdroż aplikację z PDB:
   ```bash
   kubectl apply -f app-with-pdb.yaml
   kubectl get pods -o wide -l app=critical-svc
   kubectl get pdb
   ```

3. Wybierz node z największą liczbą replik:
   ```bash
   NODE=$(kubectl get pods -l app=critical-svc -o wide --no-headers | awk '{print $7}' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
   echo "Drain target: $NODE"
   ```

4. Cordon (zaznacz unschedulable):
   ```bash
   kubectl cordon "$NODE"
   kubectl get nodes        # status: SchedulingDisabled
   ```

5. Drain — bezpieczna ewikcja:
   ```bash
   kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data
   ```
   Zwróć uwagę na komunikaty o PDB — drain czeka aż wszystkie Pody mogą być bezpiecznie usunięte.

6. Sprawdź re-scheduling:
   ```bash
   kubectl get pods -l app=critical-svc -o wide
   # Wszystkie powinny być na innych node'ach
   ```

7. **Symulacja patcha** (w realu: reboot, kernel update):
   ```bash
   sleep 10 && echo "patching done"
   ```

8. Uncordon — przywróć node do puli:
   ```bash
   kubectl uncordon "$NODE"
   ```

## Bonus — drain bez PDB

1. Spróbuj draina aplikacji bez PDB:
   ```bash
   kubectl apply -f app-without-pdb.yaml
   kubectl drain $NODE --ignore-daemonsets --delete-emptydir-data
   ```
   Drain natychmiast usunie wszystkie repliki — ryzyko downtime.


## Linki
- [Safely drain a node](https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/)
- [Specifying a PodDisruptionBudget](https://kubernetes.io/docs/tasks/run-application/configure-pdb/)
