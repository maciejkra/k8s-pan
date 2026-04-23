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
- K3s / Kind / K3d cluster
- **Ważne: rozmiar klastra wpływa na czy preemption faktycznie się odpali**. Klaster z luzem zasobów scheduler'a nie zmusi do preemption — high-priority Pod po prostu trafi na wolne miejsce.

### Tuning klastra dla demo

Manifesty są skalibrowane pod K3d/Kind z **2 workery × ~2 CPU każdy** (~4 CPU allocatable). Jeśli Twój klaster ma więcej:
- Zwiększ `replicas` w `low-priority-deployment.yaml` (żeby nasycić klaster)
- Albo zmniejsz allocatable przez utworzenie dodatkowego "resource hog" deployment przed tym ćwiczeniem

Sprawdź wolne CPU przed startem:
```bash
kubectl describe nodes | grep -A 3 "Allocated resources"
# Szukaj (cpu %)  i  (cpu Limits %)
```

## Pliki

- `priorityclasses.yaml` — 3 PriorityClass (high, normal, batch-low)
- `high-priority-pod.yaml` — Pod `critical-payment` z PriorityClass `high`, dużym `requests.cpu`
- `low-priority-deployment.yaml` — Deployment `batch-workers` z PriorityClass `batch-low`, wypełnia klaster

## Zadanie

Patrz [`task.md`](./task.md).

## Pytania kontrolne

1. Co robi `globalDefault: true` w PriorityClass? Ile klas z tą flagą może być w klastrze?
2. Co robi `preemptionPolicy: Never`? Kiedy chcesz używać?
3. Priority vs QoS (D3/02) — dwa niezależne wymiary. Pod może być Guaranteed + low priority? BestEffort + high priority?
4. Preemption a PodDisruptionBudget (D3/09) — czy PDB chroni przed preemption?
5. **Bonus**: może się zdarzyć że klaster NIE wywłaszcza mimo high-priority Pod Pending? (Tak — patrz solution.)

## Linki
- [Pod Priority and Preemption](https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/)
- [Non-preempting PriorityClass](https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/#non-preempting-priority-class)
- [Preemption + PDB interaction (K8s 1.28+)](https://github.com/kubernetes/enhancements/tree/master/keps/sig-scheduling/4537-respect-pdb-in-preemption)
