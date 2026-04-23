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
- K3s / Kind / K3d cluster z **min. 2 agentami** (żeby było gdzie ewakuować)
  - K3d: `k3d cluster create training --agents 2`
  - Kind: `kind.config.yaml` z `workers: 2`
  - K3s: kolejne `k3s agent` na drugiej VM

## Pliki

- `app-with-pdb.yaml` — Deployment 4 repliki + `PodDisruptionBudget minAvailable: 3`
- `app-without-pdb.yaml` — tylko Deployment (brak PDB) — demo ryzyka

## Zadanie

Patrz [`task.md`](./task.md).

## Pytania kontrolne

1. `--ignore-daemonsets` — dlaczego to konieczne? Co robi drain gdy widzi DaemonSet Pod?
2. `minAvailable: 50%` vs `maxUnavailable: 1` — kiedy które dla 3-node'owej bazy Redis Cluster?
3. Drain **zablokowany** przez PDB — jakie przyczyny i jak zdebugować?
4. Czy drain respektuje PriorityClass (D3/07)? (Hint: nie.)
5. **Bonus**: `kubectl drain --disable-eviction` vs bez — kiedy awaryjnie by-passować PDB?

## Linki
- [Safely drain a node](https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/)
- [Specifying a PodDisruptionBudget](https://kubernetes.io/docs/tasks/run-application/configure-pdb/)
- [Preemption + PDB interaction (K8s 1.28+)](https://github.com/kubernetes/enhancements/tree/master/keps/sig-scheduling/4537-respect-pdb-in-preemption)
- [kured — Kubernetes Reboot Daemon](https://github.com/kubereboot/kured) — automatyzacja rebootów po kernel update
