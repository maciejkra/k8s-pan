# 07 — PriorityClass + preemption

## Cel
Zobaczyć w działaniu mechanizm priorytetów i wywłaszczania (preemption) Podów, gdy klaster nie ma zasobów.

## Kontekst
W zatłoczonym klastrze nie wszystkie Pody są równe. Krytyczne workload (system, payment, monitoring) muszą działać kosztem tła (batch, CI). K8s rozwiązuje to przez:

- **PriorityClass** — globalny obiekt definiujący wartość priority (int32). Wyższa = ważniejsza.
- **Pod.spec.priorityClassName** — przypisanie klasy do Pod.
- **Preemption** — gdy nowy Pod o wyższym priority nie ma gdzie się zmieścić, kube-scheduler **usuwa** (eviction) niskie-priority Pody, żeby zrobić miejsce.

System zawiera dwie wbudowane klasy:
- `system-cluster-critical` (2_000_000_000) — komponenty klastra (kube-dns, calico)
- `system-node-critical` (2_000_001_000) — komponenty per-node (kube-proxy)

Dla aplikacji użytkownika definiujemy własne klasy (typowo: 1000 = high, 100 = normal, -10 = best-effort).

## Prereqs
- K3d cluster (`./setup-cluster.sh`)
- Klaster z ograniczonymi zasobami (K3d ma typowo 4 CPU / 8 GB — wystarczy)

## Zadanie

1. Stwórz PriorityClasses:
   ```bash
   kubectl apply -f priorityclasses.yaml
   kubectl get priorityclass
   ```

2. Wypełnij klaster Podami best-effort (niski priorytet):
   ```bash
   kubectl apply -f low-priority-deployment.yaml
   kubectl get pods -l tier=batch -o wide
   # Powinno być kilka(naście) Podów na stanie Running
   ```

3. Sprawdź dostępne zasoby:
   ```bash
   kubectl describe nodes | grep -A 5 "Allocated resources"
   ```

4. Wdroż wysoko-priorytetowy Pod, który nie zmieści się bez wywłaszczenia:
   ```bash
   kubectl apply -f high-priority-pod.yaml
   kubectl get events --sort-by='.lastTimestamp' | tail -20
   # Spodziewane: "Preempted" event na low-priority Podzie
   ```

5. Zaobserwuj, że wysoko-priorytetowy Pod jest Running, a kilka low-priority zostało wyrzuconych.

6. Sprzątnij:
   ```bash
   kubectl delete -f high-priority-pod.yaml -f low-priority-deployment.yaml -f priorityclasses.yaml
   ```

## Pytania kontrolne
1. Co to znaczy `globalDefault: true`? Co się stanie z Podami bez `priorityClassName`?
2. `preemptionPolicy: Never` — kiedy się to opłaca?
3. Jaki jest związek priority z QoS class (Guaranteed/Burstable/BestEffort)?
4. Czy preemption respektuje PodDisruptionBudget? (Hint: krótko od K8s 1.27)

## Linki
- [Pod Priority and Preemption](https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/)
- [Non-preempting PriorityClass](https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/#non-preempting-priority-class)
