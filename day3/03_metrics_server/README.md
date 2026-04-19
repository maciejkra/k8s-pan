# 03 — Metrics Server

## Cel
Zainstalować Metrics Server — wymóg dla `kubectl top` i HPA (D3/04).

## Kontekst
**Metrics Server** to lekki agregator zużycia CPU/memory per Pod/Node. Nie magazynuje historii — to **point-in-time** dane (Prometheus do długoterminowej historii — D5/04).

Eksponuje API `metrics.k8s.io/v1beta1`:
- `kubectl top nodes` — current usage per node
- `kubectl top pods` — current usage per pod
- HPA / VPA / kubectl scale --auto-scale używają tego API

Wymagany w **prawie każdym** klastrze produkcyjnym.

## Prereqs
- K3d/Kind cluster (`setup-cluster.sh` już instaluje metrics-server)

## Zadanie

1. Sprawdź czy metrics-server jest:
   ```bash
   kubectl get deployment -n kube-system metrics-server
   # Jeśli nie ma — install:
   kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
   ```

2. Patch dla K3d/Kind (kubelet używa self-signed cert):
   ```bash
   kubectl edit deployment metrics-server -n kube-system
   ```
   Dodaj args:
   ```yaml
   command:
     - /metrics-server
     - --kubelet-preferred-address-types=InternalIP
     - --kubelet-insecure-tls               # tylko dev/local!
     - --secure-port=4443
     - --cert-dir=/tmp
   ```

3. Czekaj aż Ready i sprawdź:
   ```bash
   kubectl wait --for=condition=available -n kube-system deploy/metrics-server --timeout=2m
   kubectl top nodes
   kubectl top pods -A
   ```

### Minikube alternative

```bash
minikube addons list
minikube addons enable metrics-server
```


## Linki
- [Metrics Server repo](https://github.com/kubernetes-sigs/metrics-server)
- [Metrics API design](https://github.com/kubernetes/community/blob/master/contributors/design-proposals/instrumentation/resource-metrics-api.md)
