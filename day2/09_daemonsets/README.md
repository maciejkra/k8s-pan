# 09 — DaemonSet

## Cel
Wdrożyć DaemonSet, zrozumieć jego model "jeden Pod per node" i typowe use cases.

## Kontekst
**DaemonSet** = kontroler uruchamiający **dokładnie jeden Pod na każdym (pasującym) node**. Gdy dochodzi nowy node — DaemonSet automatycznie tworzy tam Pod. Gdy node znika — Pod znika z nim.

Typowe use cases (zawsze coś per-node):
- **Log collector** (Fluent Bit, Promtail, Filebeat) — czyta `/var/log/containers/*` na każdym nodzie
- **Metrics agent** (node-exporter, DCGM exporter) — eksportuje per-node metryki
- **Networking** (CNI: Calico, Cilium, Weave) — instaluje route'y na każdym nodzie
- **Storage** (Longhorn, Ceph) — node-local storage agent
- **Security** (Falco — D4/08) — runtime detection per-node

Można ograniczyć przez `nodeSelector`/`affinity` (np. tylko nody GPU dostają DCGM exporter).

## Prereqs
- K3d/Kind cluster z 2+ node'ami

## Zadanie

1. Wdroż:
   ```bash
   kubectl apply -f .
   ```

2. Sprawdź — Pod-y na każdym worker node:
   ```bash
   kubectl get daemonset
   kubectl get pods -o wide
   # NAME            READY  NODE
   # daemon-xxxx     1/1    k3d-training-agent-0
   # daemon-yyyy     1/1    k3d-training-agent-1
   ```

3. Dodaj nowy node (jeśli używasz K3d):
   ```bash
   k3d node create extra --cluster training
   sleep 30
   kubectl get pods -o wide
   # Nowy Pod DaemonSet na nowym node
   ```

4. Usuń node:
   ```bash
   k3d node delete extra
   kubectl get pods -o wide
   # Pod DaemonSet automatycznie zniknął
   ```


## Linki
- [DaemonSet docs](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/)
- [Daemon Pods spec](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/#daemon-pods-and-replicasetcontroller)
