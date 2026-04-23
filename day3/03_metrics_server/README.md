# 03 — Metrics Server

## Cel
Zainstalować (lub zweryfikować) Metrics Server — wymóg dla `kubectl top` i HPA (D3/04).

## Kontekst
**Metrics Server** to lekki agregator zużycia CPU/memory per Pod/Node. Nie magazynuje historii — to **point-in-time** dane (Prometheus do długoterminowej historii — D5/02).

Eksponuje API `metrics.k8s.io/v1beta1`:
- `kubectl top nodes` — current usage per node
- `kubectl top pods` — current usage per pod
- HPA / VPA / `kubectl scale --auto-scale` używają tego API

Wymagany w **prawie każdym** klastrze produkcyjnym.

## Runtime compatibility (K3s / Kind / K3d)

| Runtime | Jak metrics-server? |
|---|---|
| **K3s** (wraz z K3d) | Od v1.23+ **wbudowany** (w większości dystrybucji) — `kubectl get deploy -n kube-system metrics-server`. Jeśli brak: `kubectl apply -f components.yaml` + patch args jak niżej. |
| **Kind** | **Musisz doinstalować**. `kubectl apply -f components.yaml` + patch args (`--kubelet-insecure-tls` + `--kubelet-preferred-address-types=InternalIP,Hostname,ExternalIP`) bo kubelet w Kind używa self-signed cert. |
| **Minikube** | `minikube addons enable metrics-server` |

**Dlaczego `--kubelet-preferred-address-types`?** Na Kind kubelet API zwraca `Hostname` jako primary address, który nie rozwiązuje się z metrics-server Poda. Bez tej flagi: `kubectl top nodes` → `unable to fetch pod metrics`.

## Prereqs
- K3s / Kind / K3d cluster

## Zadanie

Patrz [`task.md`](./task.md).

## Linki
- [Metrics Server repo](https://github.com/kubernetes-sigs/metrics-server)
- [Metrics API design](https://github.com/kubernetes/community/blob/master/contributors/design-proposals/instrumentation/resource-metrics-api.md)
- [Troubleshooting metrics-server](https://github.com/kubernetes-sigs/metrics-server/blob/master/FAQ.md)
