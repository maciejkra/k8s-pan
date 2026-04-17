# SETUP

## Wymagane narzędzia

| Narzędzie | Wersja | Cel |
|---|---|---|
| Docker Desktop / Rancher Desktop / OrbStack | aktualna | runtime + buildy |
| kubectl | v1.30+ | komunikacja z klastrem |
| helm | v3.14+ | instalacja chartów (Vault, cert-manager, OPA, Falco, Trivy, GPU) |
| k3d | v5.6+ | lokalny klaster K3s w Dockerze |
| trivy | v0.50+ | skanowanie obrazów (D1) |
| cosign | v2.2+ | podpisywanie obrazów (D1) |
| hadolint | v2.12+ | linter Dockerfile (D1) |
| jq | dowolna | parsowanie JSON w skryptach |

Opcjonalnie (na slajdach, bez ćwiczeń): kubectx, kubens, k9s, Lens, Telepresence.

## Instalacja (macOS / Homebrew)

```bash
brew install kubectl helm k3d trivy cosign hadolint jq
brew install --cask docker        # lub rancher / orbstack
```

## Instalacja (Linux)

```bash
# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# helm
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# k3d
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# trivy
sudo apt-get install -y wget apt-transport-https gnupg
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update && sudo apt-get install -y trivy

# cosign
curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"
sudo mv cosign-linux-amd64 /usr/local/bin/cosign && sudo chmod +x /usr/local/bin/cosign

# hadolint
sudo wget -O /usr/local/bin/hadolint https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-x86_64
sudo chmod +x /usr/local/bin/hadolint
```

## Instalacja (Windows / WSL2)

Rekomendacja: użyć WSL2 z Ubuntu i zainstalować jak w sekcji Linux.

## Pierwsze uruchomienie klastra

```bash
./setup-cluster.sh
kubectl get nodes
```

Skrypt postawi K3d cluster (3 nody) + zainstaluje Envoy Gateway, cert-manager, metrics-server. fake-gpu-operator instaluje się osobno (D5/07).

## Reset klastra

```bash
k3d cluster delete training
./setup-cluster.sh
```

## Helm repos używane w kursie

```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo add jetstack https://charts.jetstack.io
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo add aqua https://aquasecurity.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add fake-gpu-operator https://fake-gpu-operator.storage.googleapis.com
helm repo update
```

## Troubleshooting

| Problem | Rozwiązanie |
|---|---|
| `metrics-server` CrashLoopBackOff na K3d | Skrypt setup automatycznie dodaje `--kubelet-insecure-tls` |
| Envoy Gateway nie odpowiada | `kubectl get svc -n envoy-gateway-system` — sprawdź LoadBalancer; na K3d porty są mapowane przez `--port` flagę |
| cert-manager challenge nie przechodzi | Lokalnie używaj **staging** Let's Encrypt + ngrok/cloudflared dla publicznego DNS, lub testuj samosignowane przez ClusterIssuer typu CA |
| `nvidia.com/gpu` resource not found | `helm install fake-gpu-operator …` z odpowiednim ConfigMap topology — patrz `day5/07_ai_gpu/01_install_fake_gpu/` |
