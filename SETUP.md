# SETUP

Instalacja narzędzi + setup klastra dla szkolenia. Każdy uczestnik wybiera jeden z trzech runtime: **K3s**, **Kind** lub **K3d**.

---

## 1. Wymagane narzędzia

| Narzędzie | Wersja | Cel |
|---|---|---|
| Docker Desktop / Rancher Desktop / OrbStack | aktualna | runtime + buildy |
| kubectl | v1.30+ | komunikacja z klastrem |
| helm | v3.14+ | instalacja chartów |
| Jeden z: `k3d` (v5.6+), `kind` (v0.26+), `k3s` (v1.34+) | — | lokalny klaster |
| trivy | v0.50+ | skanowanie obrazów (D1, D4/07) |
| cosign | v2.2+ | podpisywanie obrazów (D1, D4 supply chain) |
| hadolint | v2.12+ | linter Dockerfile (D1) |
| jq / yq | dowolna | parsowanie JSON/YAML w skryptach |

Opcjonalnie (na slajdach): kubectx, kubens, k9s, Lens, Telepresence.

### Instalacja (macOS / Homebrew)

```bash
brew install kubectl helm k3d kind trivy cosign hadolint jq yq
brew install --cask docker        # lub rancher / orbstack
```

### Instalacja (Linux Ubuntu/Debian)

```bash
# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# helm
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# k3d (opcjonalne)
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# kind (opcjonalne)
go install sigs.k8s.io/kind@v0.27.0   # lub pobierz binary z releases

# trivy, cosign, hadolint — patrz docs
```

### Instalacja (Windows / WSL2)

Rekomendacja: użyć WSL2 z Ubuntu i zainstalować jak w sekcji Linux.

---

## 2. Runtime compatibility

Ten training jest przygotowany pod **trzy runtime**. Wybierz ten który Ci pasuje — każde ćwiczenie działa na wszystkich trzech (z uwagami gdzie są różnice).

| Aspekt | **K3s** (bare Linux) | **K3d** (K3s w Dockerze) | **Kind** |
|---|---|---|---|
| Where | Linux VM / bare-metal | Docker (macOS/Linux/Windows) | Docker |
| Load Balancer | Klipper built-in | Klipper + `--port` mapping | wymaga MetalLB / `cloud-provider-kind` |
| Default CNI | Flannel | Flannel | kindnet |
| NetworkPolicy | **NIE** (Flannel) → install Cilium | **NIE** → install Cilium | ingress v0.20+, egress v0.26+ |
| metrics-server | zwykle built-in od 1.23+ | built-in | install manualnie |
| GPU support | realne + fake-gpu-operator | fake-gpu-operator | fake-gpu-operator |
| Szybkość bootu | ~10s | ~30s | ~60s |
| Best for | Linux devs, production-like | macOS devs, "K3s w Dockerze" | waniliowy K8s, Kind-native community |

### Który wybrać?

- **macOS / Windows** + proste demo → **K3d** (lub Rancher Desktop który używa K3d wewnątrz).
- **Linux** + testowanie blisko produkcji → **K3s**.
- **Testowanie waniliowego K8s** (CIS audit z D4/06, MutatingAdmissionPolicy alpha) → **Kind**.

### Wiele klastrów naraz

Każdy runtime wspiera:
```bash
k3d cluster list
kind get clusters
k3s kubectl config get-contexts    # jeśli multiple K3s installed via systemd
```

Przełączanie: `kubectl config use-context <name>` lub `kubectx <name>` (CLI tool).

---

## 3. Setup K3d (shortcut — dla szybkiego demo)

```bash
./setup-cluster.sh
kubectl get nodes
```

Skrypt:
1. Tworzy K3d cluster `training` (1 server + 2 agents, port 80/443 mapped).
2. Instaluje Envoy Gateway + cert-manager + metrics-server.
3. fake-gpu-operator instaluje się osobno (D5/04).

Reset:
```bash
k3d cluster delete training
./setup-cluster.sh
```

**Wariant z Cilium** (dla D3/08 NetworkPolicy):
```bash
k3d cluster create training \
  --servers 1 --agents 2 \
  --port "80:80@loadbalancer" \
  --port "443:443@loadbalancer" \
  --k3s-arg '--disable=traefik@server:0' \
  --k3s-arg '--flannel-backend=none@server:*' \
  --k3s-arg '--disable-network-policy=false@server:*'

# Install Cilium
cilium install --version 1.17.6
cilium status --wait
```

---

## 4. Setup Kind (dla waniliowego K8s)

Utwórz `kind.config.yaml`:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
      - containerPort: 443
        hostPort: 443
  - role: worker
  - role: worker
# Dla metrics-server scraping:
kubeadmConfigPatches:
  - |-
    kind: ClusterConfiguration
    controllerManager:
      extraArgs:
        bind-address: 0.0.0.0
    etcd:
      local:
        extraArgs:
          listen-metrics-urls: http://0.0.0.0:2381
    scheduler:
      extraArgs:
        bind-address: 0.0.0.0
```

Stwórz klaster:
```bash
kind create cluster --config kind.config.yaml --name training
```

### MetalLB (dla `type: LoadBalancer` Services)

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml
kubectl wait --namespace metallb-system --for=condition=ready pod --selector=app=metallb --timeout=90s

# IPAddressPool z zakresem Docker bridge (typowo 172.18.255.200-250)
DOCKER_SUBNET=$(docker network inspect kind -f '{{(index .IPAM.Config 0).Subnet}}')
# Wyciągnij pool z zakresu subnet (np. 172.18.255.200-172.18.255.250)

cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata: { name: default, namespace: metallb-system }
spec:
  addresses: [172.18.255.200-172.18.255.250]
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata: { name: default, namespace: metallb-system }
EOF
```

### Envoy Gateway + cert-manager (Kind)

```bash
# Envoy Gateway
helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v0.0.0-latest \
  -n envoy-gateway-system --create-namespace
kubectl wait --timeout=5m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available

# cert-manager
helm upgrade --install cert-manager jetstack/cert-manager \
  -n cert-manager --create-namespace \
  --set crds.enabled=true
```

### Metrics-server (Kind)

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system --type=json -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"},
  {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-preferred-address-types=InternalIP,Hostname,ExternalIP"}
]'
kubectl wait --timeout=3m -n kube-system deployment/metrics-server --for=condition=Available
```

### Cilium (dla D3/08 NetworkPolicy na Kind)

```bash
# Alternative — wyłącz kindnet, install Cilium
kind create cluster --config kind.config.yaml --name training-cilium -- \
  # Uwaga: kind nie wspiera --no-default-cni przez flagę, trzeba inaczej:
  # Patrz: https://docs.cilium.io/en/stable/installation/kind/
```

Alternatywa bez reinstall klastra: **kindnet v0.26+** natywnie wspiera NetworkPolicy (ingress + egress) — jeśli Twój Kind jest >=0.26, zwyczajny `kubectl apply NetworkPolicy` zadziała.

---

## 5. Setup K3s (bare Linux / VM)

Na Linux VM (Ubuntu 22.04+):

```bash
# Install K3s (standalone, bez Docker)
curl -sfL https://get.k3s.io | sh -s - \
  --disable=traefik \
  --disable=servicelb \
  --write-kubeconfig-mode=644

# Dla Cilium kube-proxy-replacement:
# curl -sfL https://get.k3s.io | sh -s - \
#   --disable=traefik --disable=servicelb --disable-kube-proxy \
#   --flannel-backend=none

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes
```

Dodaj agenty (worker nodes):
```bash
# Na master:
K3S_TOKEN=$(cat /var/lib/rancher/k3s/server/node-token)

# Na agent VM:
curl -sfL https://get.k3s.io | K3S_URL=https://<master-ip>:6443 K3S_TOKEN=<token> sh -
```

Potem Envoy Gateway + cert-manager + metrics-server jak dla Kind.

---

## 6. Helm repos używane w kursie

```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo add jetstack https://charts.jetstack.io
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo add aqua https://aquasecurity.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add fake-gpu-operator https://fake-gpu-operator.storage.googleapis.com
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
```

---

## 7. Troubleshooting

| Problem | Rozwiązanie |
|---|---|
| `metrics-server` CrashLoopBackOff | Dodaj `--kubelet-insecure-tls` (Kind/K3d) |
| Envoy Gateway nie odpowiada | Sprawdź że port 80/443 mapowany (K3d: `--port` flag; Kind: `extraPortMappings`) |
| cert-manager challenge nie przechodzi | Lokalnie staging Let's Encrypt + ngrok/cloudflared; albo self-signed ClusterIssuer |
| NetworkPolicy nic nie blokuje | CNI nie wspiera NP → K3s/K3d: install Cilium; Kind: sprawdź kindnet ≥0.26 |
| `nvidia.com/gpu` resource not found | `helm install fake-gpu-operator …` z `topology.yaml` — patrz `day5/04_ai_gpu/01_install_fake_gpu/` |
| `kubectl top` nie działa | Metrics-server nie gotowe (~30s po starcie) lub brak `--kubelet-insecure-tls` |
| Kind: `LoadBalancer` Service w `Pending` | Install MetalLB (sekcja 4 wyżej) |

---

## 8. Verify installation

Po setup:
```bash
# Runtime
kubectl get nodes -o wide
kubectl cluster-info

# Core addons
kubectl get pods -n envoy-gateway-system
kubectl get pods -n cert-manager
kubectl top nodes

# Gateway API CRDs zainstalowane
kubectl get gatewayclass
```

Gotowy — przechodź do `day1/01_nginx_image/`.
