# 04 — Tworzenie klastra Kind + pierwsze komendy kubectl

## Cel
Postawić lokalny klaster Kubernetes (Kind), zweryfikować dostęp i poznać podstawowe komendy `kubectl` do diagnostyki klastra.

## Kontekst
[Kind](https://kind.sigs.k8s.io/) (Kubernetes IN Docker) — uruchamia K8s w kontenerach Docker. Lekki, szybki, idealny do nauki i CI. Alternatywy: K3d (nasz default w `setup-cluster.sh`), Minikube, k3s natywnie.

`kubectl` używa pliku `~/.kube/config` (kubeconfig) — mapuje **clusters**, **users**, **contexts**. Po `kind create cluster` automatycznie dodaje nowy context i ustawia jako current.

## Prereqs
- Docker (dla Kind)
- `kubectl` (`brew install kubectl`)
- `kind` (`brew install kind`)

## Zadanie

1. Zmień `hostPath` w `kind.yaml` (Windows: `/c/path/to/file`).

2. Stwórz klaster:
   ```bash
   kind create cluster --config ./kind.yaml --name workshop
   ```

3. Sprawdź context i klaster:
   ```bash
   kubectl config current-context
   kubectl config get-contexts
   kubectl cluster-info
   ```

4. Verbose mode (debug API calls):
   ```bash
   kubectl get pods -v=9
   ```
   Zobaczysz pełne HTTP requesty do API serwera — przydatne przy debugowaniu auth/RBAC.

5. Bonus — krew plugin manager:
   ```bash
   kubectl krew install konfig
   kubectl konfig import -s <kubeconfig-file>
   ```

## Uwaga: kind + Envoy Gateway (data-plane na control-plane)

`kind.yaml` w tym ćwiczeniu mapuje porty 80/443 **tylko na control-plane** node i nadaje mu label `ingress-ready=true`. Problem: control-plane ma domyślny taint `node-role.kubernetes.io/control-plane:NoSchedule`, więc Envoy Gateway data-plane pod (ten, który kontroler tworzy po zaaplikowaniu pierwszego `Gateway`) bez explicit toleration ląduje na workerze — a worker nie ma zmapowanych 80/443 na host. Efekt: `curl http://localhost/` z hosta nie trafia w Envoya.

K3d z `setup-cluster.sh` tego problemu nie ma (server:0 jest bez tainta, a LoadBalancer k3d eksponuje 80/443 niezależnie od node). **Tylko jeśli używasz kind** (tego `kind.yaml`), po zainstalowaniu Envoy Gateway z D2/07 i **przed** utworzeniem pierwszego `Gateway` zaaplikuj `envoyproxy-kind.yaml`:

```bash
# Pin data-plane Envoya na control-plane (nodeSelector + toleration)
kubectl apply -f day1/03_k8s/envoyproxy-kind.yaml

# Podepnij EnvoyProxy CR pod GatewayClass "eg"
kubectl patch gatewayclass eg --type=merge -p '{
  "spec": {
    "parametersRef": {
      "group": "gateway.envoyproxy.io",
      "kind":  "EnvoyProxy",
      "name":  "kind-control-plane",
      "namespace": "envoy-gateway-system"
    }
  }
}'

# Weryfikacja po stworzeniu Gateway z D2/07 — data-plane pod ma być na control-plane
kubectl get pods -n envoy-gateway-system -o wide
# NAME                     ... NODE
# envoy-eg-...             ... workshop-control-plane
```

## Linki
- [Kind quick start](https://kind.sigs.k8s.io/docs/user/quick-start/)
- [kubectl cheatsheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [krew plugin manager](https://krew.sigs.k8s.io/)
