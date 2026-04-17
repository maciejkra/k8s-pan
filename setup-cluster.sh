#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-training}"

echo "==> 1/5 K3d cluster ($CLUSTER_NAME)"
if k3d cluster list | grep -q "^$CLUSTER_NAME "; then
  echo "    Cluster '$CLUSTER_NAME' już istnieje. Pomijam."
else
  k3d cluster create "$CLUSTER_NAME" \
    --servers 1 --agents 2 \
    --port "80:80@loadbalancer" \
    --port "443:443@loadbalancer" \
    --k3s-arg "--disable=traefik@server:0"
fi

kubectl config use-context "k3d-$CLUSTER_NAME"

echo "==> 2/5 Envoy Gateway (Gateway API impl) — D2/07"
helm repo add jetstack https://charts.jetstack.io 2>/dev/null || true
helm repo update
helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v0.0.0-latest \
  -n envoy-gateway-system --create-namespace
kubectl wait --timeout=5m -n envoy-gateway-system \
  deployment/envoy-gateway --for=condition=Available

echo "==> 3/5 cert-manager — D2/07 + D4 (Vault TLS)"
helm upgrade --install cert-manager jetstack/cert-manager \
  -n cert-manager --create-namespace \
  --set crds.enabled=true
kubectl wait --timeout=5m -n cert-manager \
  deployment/cert-manager --for=condition=Available

echo "==> 4/5 metrics-server — D3/04 (HPA)"
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
kubectl wait --timeout=3m -n kube-system \
  deployment/metrics-server --for=condition=Available || true

echo "==> 5/5 Status klastra"
kubectl get nodes
echo ""
echo "Cluster '$CLUSTER_NAME' gotowy."
echo "Następne kroki:"
echo "  - D5/07 GPU:        helm install gpu-operator fake-gpu-operator/fake-gpu-operator -f day5/07_ai_gpu/01_install_fake_gpu/topology.yaml"
echo "  - D4/04 Vault:      patrz day4/04_vault/README.md"
echo "  - D5/04 Monitoring: patrz day5/04_monitoring_alerting/README.md"
