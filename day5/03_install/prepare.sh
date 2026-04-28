#!/usr/bin/env bash
# Prepare Ubuntu 24.04 node for kubeadm install (k8s v1.35).
# Uruchom na KAŻDYM z 6 node'ów jako root (lub sudo).
set -euo pipefail

# Cloud bootstrap niezawodny: zaczekaj aż cloud-init skończy (DO + inne providery
# odpalają unattended-upgrades przy pierwszym boot, blokuje dpkg lock), wycisz
# noninteractive frontends, zmask serwisy bijące się o apt lock w trakcie skryptu.
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1

if command -v cloud-init >/dev/null 2>&1; then
  echo "==> Waiting for cloud-init to finish..."
  sudo cloud-init status --wait || true
fi

echo "==> Masking unattended-upgrades + apt-daily timers"
sudo systemctl mask --now \
  apt-daily.service apt-daily-upgrade.service \
  apt-daily.timer apt-daily-upgrade.timer \
  unattended-upgrades.service 2>/dev/null || true

echo "==> Waiting for apt/dpkg locks..."
while sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1 \
   || sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 \
   || sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1 \
   || sudo fuser /var/cache/apt/archives/lock >/dev/null 2>&1; do
    echo "Waiting for other software managers to finish..."
    sleep 10
done

echo "==> Install containerd (Docker APT repo)"
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y containerd.io

# Containerd config — default + SystemdCgroup=true (wymagane dla k8s)
sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

echo "==> Kernel modules (overlay, br_netfilter)"
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

echo "==> sysctl (forwarding, bridge-nf)"
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

echo "==> Disable swap (kubelet wymaga)"
sudo sed -i '/swap/d' /etc/fstab
sudo swapoff -a

echo "==> K8s v1.35 APT repo"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key | \
  sudo gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
# Pin do v1.35.3 — żeby `kubernetesVersion` w kubeadm-config zgadzała się z binarami.
sudo DEBIAN_FRONTEND=noninteractive apt-get install --allow-downgrades --allow-change-held-packages -y \
  kubelet=1.35.3-1.1 kubeadm=1.35.3-1.1 kubectl=1.35.3-1.1

# Hold packages — no unattended upgrade
sudo apt-mark hold kubelet kubeadm kubectl

# Enable kubelet (kubeadm init/join wystartuje go, ale po reboocie chcemy auto-start)
sudo systemctl enable kubelet

echo ""
echo "=========================================="
echo "Node gotowy na kubeadm init / join."
echo "=========================================="
