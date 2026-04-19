# 06 — Scheduling rules (affinity, taints, topology spread)

## Cel
Opanować mechanizmy wpływające na decyzje K8s schedulera — gdzie Pody trafiają i gdzie nie.

## Kontekst
Default scheduler (kube-scheduler) używa dwufazowego algorytmu:
1. **Filtering** — które nody spełniają twarde wymagania Pod-a? (resources, nodeSelector, taints, affinity required)
2. **Scoring** — które z pozostałych są "najlepsze"? (affinity preferred, balanced allocation, image locality)

Trzy mechanizmy user-facing:

| Mechanizm | Efekt | Podkatalog |
|---|---|---|
| **Node/Pod Affinity** | preferuj / wymagaj konkretnej lokalizacji | `01_afinity.yaml/` |
| **Taints + Tolerations** | oznacz node "nie planuj tu bez zgody" | `02_taints/` |
| **Topology Spread Constraints** | rozrzuć repliki po domenach | `03_tsc/` |

**Kluczowa zasada**: każdy z tych mechanizmów jest komplementarny, nie alternatywny. W produkcji zazwyczaj używa się kombinacji.

## Plan ćwiczeń

1. [`01_afinity.yaml/`](./01_afinity.yaml/) — nodeAffinity + podAffinity + antiAffinity
2. [`02_taints/`](./02_taints/) — taints, tolerations, NoSchedule/NoExecute
3. [`03_tsc/`](./03_tsc/) — Topology Spread Constraints (rozrzut po zone/hostname)

## Przykłady produkcyjne

- **GPU node pool** (D5/04): taint `nvidia.com/gpu=true:NoSchedule` + nodeSelector `nvidia.com/gpu.present=true` na GPU workloads
- **Spot instances**: taint `spot=true:NoSchedule` + toleration na Podach tolerujących interruption
- **Multi-zone HA**: TSC `maxSkew: 1, topologyKey: topology.kubernetes.io/zone` — każda zone dostaje równą liczbę replik
- **Database leader isolation**: podAntiAffinity `required` + `topologyKey: kubernetes.io/hostname` — nie 2 repliki DB na jednym node

## Linki
- [Scheduler architecture](https://kubernetes.io/docs/concepts/scheduling-eviction/kube-scheduler/)
- [Scheduler profiles (custom scheduling)](https://kubernetes.io/docs/reference/scheduling/config/#profiles)
