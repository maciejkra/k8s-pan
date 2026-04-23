# 02 — Taints i Tolerations

## Cel
Dodać taint do node (oznacz: "nie planuj tu Pod-ów"), zaobserwować że Pody bez tolerations nie lądują, dodać toleration i sprawdzić że teraz ląduje. Sprawdzić NoExecute (ewikcja).

## Kontekst
**Taint** = właściwość node (np. `key=value:NoSchedule`). **Toleration** = zgoda Pod-a na dany taint. Scheduler nie umieści Pod-a na tainted node, chyba że Pod ma odpowiedni toleration.

Trzy efekty:
- **NoSchedule** — nowe Pody bez toleration nie trafią tu
- **PreferNoSchedule** — "soft" NoSchedule (scheduler spróbuje uniknąć, ale nie wymusza)
- **NoExecute** — jak NoSchedule + **ewikuje** istniejące Pody bez toleration

Typowe produkcyjne use cases:
- GPU nodes tainted — tylko GPU workloads (D5/04)
- Spot instances tainted — tylko workloads tolerujące interruption
- Dedicated node pools per team — `dedicated=data-science:NoSchedule`

Built-in taints (automatic):
- `node.kubernetes.io/not-ready:NoExecute` — kubelet sygnalizuje awarię node
- `node.kubernetes.io/unreachable:NoExecute`
- `node-role.kubernetes.io/control-plane:NoSchedule` — CP nody default tainted **na Kind** (K3s/K3d zwykle nie taintują CP domyślnie)

## Prereqs
- K3s / Kind / K3d cluster z min. 2 node'ami

## Zadanie

### Przygotowanie — zdobądź nazwę node

```bash
# Wybierz worker node (na K3d: k3d-training-agent-0; na Kind: kind-worker; na K3s: twój hostname)
NODE=$(kubectl get nodes --selector='!node-role.kubernetes.io/control-plane' -o name | head -1 | cut -d/ -f2)
echo "Używam node: $NODE"
```

### Taint NoSchedule

1. Tainuj node:
   ```bash
   kubectl taint nodes "$NODE" dedicated=workshop:NoSchedule
   ```

2. Wdroż Pod **bez** tolerations (domyślny z manifest):
   ```bash
   kubectl apply -f python-deployment.yaml
   kubectl describe pod -l app=taints-demo | tail -20
   # Events: 0/N nodes available: N node(s) had untolerated taint
   ```

   Uwaga: jeśli masz więcej niż 1 worker, Pod zescheduluje się na **drugiego** workera który nie jest tainted. Tainuj WSZYSTKICH workerów żeby wymusić Pending.

3. Odkomentuj `tolerations` w `python-deployment.yaml` (linie 23-27) i re-apply:
   ```bash
   kubectl apply -f python-deployment.yaml
   kubectl get pod -l app=taints-demo -o wide
   # Pod teraz na tainted node
   ```

4. Cleanup — usuń taint:
   ```bash
   kubectl taint nodes "$NODE" dedicated=workshop:NoSchedule-
   ```

### Taint NoExecute (ewikcja istniejących)

1. Zacznij od Poda który już działa (z tolerations od poprzedniego kroku odkomentowanymi):
   ```bash
   kubectl get pod -l app=taints-demo -o wide
   ```

2. Dodaj **inny** taint NoExecute (którego Pod nie toleruje):
   ```bash
   kubectl taint nodes "$NODE" eviction=true:NoExecute
   kubectl get pods -l app=taints-demo -w
   # Pod zostaje ewikuowany (Terminating), Deployment tworzy nowy który też nie może się umieścić
   ```

3. Cleanup:
   ```bash
   kubectl taint nodes "$NODE" eviction=true:NoExecute-
   ```

## Pytania

1. Taint + toleration vs `nodeSelector`/`nodeAffinity` — kiedy które? (Hint: kierunek kontroli.)
2. `tolerationSeconds` — po co? (Hint: grace period przy NoExecute — domyślnie 300s dla `not-ready`/`unreachable`.)
3. Czy można mieć wiele taintów na jednym node? Jak Pod matchuje "wszystkie"?
4. Built-in taint `node-role.kubernetes.io/control-plane:NoSchedule` — co znaczy? Jak uruchomić DaemonSet (D2/09) na CP? (Patrz tamten solution.md.)
5. **Bonus**: `kubectl drain` (D3/09) używa NoExecute wewnętrznie. Jak to działa?

## Linki
- [Taints and Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)
- [Well-known taints](https://kubernetes.io/docs/reference/labels-annotations-taints/)
