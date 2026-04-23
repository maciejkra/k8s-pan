# 09 — DaemonSet

## Cel
Wdrożyć DaemonSet, zrozumieć jego model "jeden Pod per node", zobaczyć **realistyczny** use case (node-exporter — scraper metryk per-host).

## Kontekst
**DaemonSet** = kontroler uruchamiający **dokładnie jeden Pod na każdym (pasującym) node**. Gdy dochodzi nowy node — DaemonSet automatycznie tworzy tam Pod. Gdy node znika — Pod znika z nim.

Typowe use cases (zawsze coś per-node):
- **Log collector** (Fluent Bit, Promtail, Filebeat) — czyta `/var/log/containers/*` na każdym nodzie
- **Metrics agent** (node-exporter, DCGM exporter) — eksportuje per-node metryki
- **Networking** (CNI: Calico, Cilium, Weave) — instaluje route'y na każdym nodzie
- **Storage** (Longhorn, Ceph) — node-local storage agent
- **Security** (Falco — D4/08) — runtime detection per-node

Można ograniczyć przez `nodeSelector`/`affinity` (np. tylko nody GPU dostają DCGM exporter).

### Kluczowe właściwości

- **Tolerations for control-plane** — systemowe DaemonSety (log/metric/CNI) zwykle muszą wylądować **też na control-plane**, nie tylko na workerach. Kind domyślnie taintuje CP (`node-role.kubernetes.io/control-plane:NoSchedule`), K3s/K3d domyślnie nie. Dla przenośności manifestu **zawsze daj tolerations** dla obu taintów.
- **UpdateStrategy** — domyślnie `RollingUpdate` (zastępuje Pody po jednym). Alternatywa: `OnDelete` (nic nie robi aż admin `kubectl delete pod`).
- **HostPath + hostNetwork** — typowe dla DS które potrzebują dostępu do filesystem hosta albo muszą słuchać na konkretnym porcie (node-exporter:9100).

## Prereqs
- K3s / Kind / K3d cluster z 2+ node'ami (dla Kind: `kind.config.yaml` z `workers: 2`)

## Pliki

- `daemonset.yaml` — node-exporter (prometheus scraper) z tolerations, hostPath, hostNetwork

## Zadanie

Patrz [`task.md`](./task.md).

## Linki
- [DaemonSet docs](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/)
- [Update strategies](https://kubernetes.io/docs/tasks/manage-daemon/update-daemon-set/)
- [Taints & tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)
- [node-exporter metrics list](https://github.com/prometheus/node_exporter)
