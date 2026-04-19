# 02 — Taints i Tolerations

## Cel
Dodać taint do node (oznacz: "nie planuj tu Pod-ów"), zaobserwować że Pody bez tolerations nie lądują, dodać toleration i sprawdzić że teraz ląduje. Sprawdzić NoExecute (ewikcja).

## Kontekst
**Taint** = właściwość node (np. `key=value:NoSchedule`). **Toleration** = zgoda Pod-a na dany taint. Scheduler nie umieści Pod-a na tainted node, chyba że Pod ma odpowiedni toleration.

Trzy effecty:
- **NoSchedule** — nowe Pody bez toleration nie trafią tu
- **PreferNoSchedule** — "soft" NoSchedule (scheduler spróbuje uniknąć, ale nie wymusza)
- **NoExecute** — jak NoSchedule + **ewikuje** istniejące Pody bez toleration

Typowe produkcyjne use cases:
- GPU nodes tainted — tylko GPU workloads (D5/07)
- Spot instances tainted — tylko workloads tolerujące interruption
- Dedicated node pools per team — `team=data-science:NoSchedule`

Built-in taints (automatic):
- `node.kubernetes.io/not-ready:NoExecute` — kubelet sygnalizuje awarię node
- `node.kubernetes.io/unreachable:NoExecute`
- `node-role.kubernetes.io/control-plane:NoSchedule` — CP nody default tainted

## Prereqs
- K3d/Kind cluster z min. 2 node'ami

## Zadanie

### Taint NoSchedule

1. Tainuj node:
   ```bash
   kubectl taint nodes ubuntu2 key=value:NoSchedule
   ```

2. Wdroż Pod bez toleration:
   ```bash
   kubectl apply -f python-deployment.yaml
   kubectl describe pod -l app=python-taints
   # Pending: 0/N nodes available
   ```

3. Odkomentuj `tolerations` w `python-deployment.yaml` i zaaplikuj ponownie:
   ```bash
   kubectl apply -f python-deployment.yaml
   kubectl describe pod -l app=python-taints
   # Scheduled na tainted node
   ```

4. Usuń taint:
   ```bash
   kubectl taint nodes ubuntu2 key:NoSchedule-
   ```

### Taint NoExecute (ewikcja istniejących)

1. Running Pod na node bez tainta — wszystko OK.

2. Dodaj NoExecute taint:
   ```bash
   kubectl taint nodes ubuntu2 key=value1:NoExecute
   kubectl get pods -w
   # Pody bez odpowiedniego toleration zostaną ewikuowane (Terminating)
   ```

3. Usuń:
   ```bash
   kubectl taint nodes ubuntu2 key=value1:NoExecute-
   ```

## Pytania kontrolne
1. Taint + toleration vs nodeSelector — kiedy które?
2. `tolerationSeconds` — po co? (Hint: grace period przy NoExecute)
3. Czy można mieć wiele taintów na jednym node? Jak Pod matchuje "wszystkie"?
4. Built-in taint `node-role.kubernetes.io/control-plane:NoSchedule` — co znaczy? Jak zaplanować workload na CP (single-node cluster)?

## Linki
- [Taints and Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)
- [Well-known taints](https://kubernetes.io/docs/reference/labels-annotations-taints/)
