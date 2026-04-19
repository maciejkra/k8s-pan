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


## Linki
- [Kind quick start](https://kind.sigs.k8s.io/docs/user/quick-start/)
- [kubectl cheatsheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [krew plugin manager](https://krew.sigs.k8s.io/)
