# 03 — ResourceQuota i LimitRange

## Cel
Wymusić limity zasobów na poziomie namespace (`ResourceQuota`) i ustawić **defaulty** dla Pod-ów które nie wyspecyfikowały requests/limits (`LimitRange`).

## Kontekst
Bez kontroli — ktoś z teamu A może wziąć cały klaster przez `replicas: 1000`. Trzy mechanizmy:

1. **ResourceQuota** — limit per **namespace**: max suma CPU/memory/Pod count/PVC count/services
2. **LimitRange** — defaulty + min/max **per Pod/container** w namespace (auto-injection requests/limits jeśli brak)
3. **PriorityClass** (D3/07) — kto ma pierwszeństwo gdy klaster pełny

Typowy setup produkcyjny:
- ClusterRole `quota-admin` przypisany do platform team
- Każdy team-namespace dostaje ResourceQuota wg swojego budżetu
- LimitRange wymusza `requests` żeby aplikacje bez ustawień nie krzywiły schedulingu

## Razem: ResourceQuota + LimitRange

**Scenariusz**: Pod bez `requests`. Bez LimitRange — ResourceQuota odrzuci Pod (wymaga requests!). Z LimitRange — defaulty wstrzyknięte, Pod policzy się do quota.

**Wniosek**: jeśli dajesz NS ResourceQuota dla `requests.*`/`limits.*` — **zawsze** dołącz LimitRange z defaultRequest/default. Inaczej blame jest "tajemniczy".

## Prereqs
- K3s / Kind / K3d cluster

## Pliki

- `ns-quota.yaml` — Namespace + ResourceQuota + LimitRange razem (jeden file)
- `deployment.yaml` — Deployment bez `resources:` — LimitRange dorzuci defaulty

## Zadanie

Patrz [`task.md`](./task.md).

## Linki
- [Resource Quotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/)
- [Limit Ranges](https://kubernetes.io/docs/concepts/policy/limit-range/)
- [Scheduler architecture](https://kubernetes.io/docs/concepts/scheduling-eviction/kube-scheduler/)
- [Best practice: namespace-level governance](https://kubernetes.io/docs/tasks/administer-cluster/manage-resources/cpu-default-namespace/)
