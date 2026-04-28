# Zadanie — manualna instalacja klastra (3 CP + 3 worker + kube-vip + Cilium)

## Część 0 — Przygotuj infrastrukturę

Uruchom 6 VM (Ubuntu 24.04) z przynajmniej 2 CPU, 2 GB RAM, 20 GB disk. Zobacz README sekcję "Testing approaches".

Zweryfikuj że node'y widzą się wzajemnie (to samo private network / VPC):
```bash
# Na cpnode1:
ping -c 2 10.135.0.7    # cpnode2
ping -c 2 10.135.0.2    # knode1
```

Wygeneruj klucz szyfrujący Secrets (placeholder w `kubernetes/enc.yaml`):
```bash
NEW_KEY=$(head -c 32 /dev/urandom | base64)
sed -i.bak "s|REPLACE_ME_BASE64_32B|${NEW_KEY}|" kubernetes/enc.yaml
grep secret kubernetes/enc.yaml
```

## Część 1 — Przygotuj KAŻDY z 6 node'ów

Skopiuj `prepare.sh` na każdy node i uruchom:

```bash
# Na każdym z 6 node'ów:
scp prepare.sh user@<ip>:/tmp/
ssh user@<ip>
chmod +x /tmp/prepare.sh && sudo /tmp/prepare.sh
```

`prepare.sh` instaluje: containerd, kubeadm/kubelet/kubectl v1.35, sysctl (forwarding, bridge-nf), disable swap, enable kubelet.

## Część 2 — Setup pierwszego CP node (cpnode1)

```bash
ssh user@10.135.0.5     # cpnode1

# Hostname
sudo hostnamectl set-hostname cpnode1

# /etc/hosts (wklej content z hosts file)
sudo bash -c 'cat > /etc/hosts' <<'EOF'
127.0.0.1 localhost
10.135.0.5 cpnode1.example.com cpnode1
10.135.0.7 cpnode2.example.com cpnode2
10.135.0.3 cpnode3.example.com cpnode3
10.135.0.2 knode1.example.com knode1
10.135.0.6 knode2.example.com knode2
10.135.0.4 knode3.example.com knode3
10.135.0.100 kubeapi.example.com kubeapi
EOF

# Dodaj VIP tymczasowo na tym node (żeby kubeadm init mógł dotrzeć do siebie przez VIP)
# ZMIEŃ `eth1` na swój network interface (`ip a` pokaże nazwy)
sudo ip a a dev eth1 10.135.0.100/32

# Skopiuj kubernetes/* do /etc/kubernetes/ (audit + encryption)
sudo mkdir -p /etc/kubernetes
sudo cp kubernetes/audit-policy.yaml /etc/kubernetes/
sudo cp kubernetes/enc.yaml /etc/kubernetes/
sudo mkdir -p /var/log/kubernetes/audit

# Kluczowe: kube-vip jako STATIC POD, deploy PRZED kubeadm init
# Edytuj kube-vip-static-pod.yaml:
#  - vip_interface: eth1 → twoj interface (DO Ubuntu 24.04: eth0; bare-metal: `ip a`)
#  - address: 10.135.0.100 → twoj VIP
sudo mkdir -p /etc/kubernetes/manifests
sudo cp kube-vip-static-pod.yaml /etc/kubernetes/manifests/kube-vip.yaml

# Init klastra (Cilium zastępuje kube-proxy — skip faze).
# UWAGA na DO: prepare.sh już zaktualizował advertiseAddress w /root/kubeadm-config.yaml
# na real eth0 IP (sprawdź: `grep advertiseAddress /root/kubeadm-config.yaml`).
# Bare-metal: zedytuj advertiseAddress + certSANs przed odpaleniem.
sudo kubeadm init --config /root/kubeadm-config.yaml --upload-certs \
  --skip-phases=addon/kube-proxy

# ⚠️ ZACHOWAJ wyjście — są tam 2 komendy kubeadm join (dla CP i worker)!
# Cert-key (--certificate-key) WYGASA po 2h. Jeśli przeciągniesz, regeneruj:
#   sudo kubeadm init phase upload-certs --upload-certs
```

Setup kubectl dla twojego usera:
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

## Część 3 — Zainstaluj Cilium CNI

```bash
# Cilium CLI
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
[ "$(uname -m)" = "aarch64" ] && CLI_ARCH=arm64
curl -L --fail --remote-name-all \
  https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz

# Install Cilium z kube-proxy replacement
cilium install --version 1.18.9 \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost=kubeapi.example.com \
  --set k8sServicePort=6443

cilium status --wait
# Cilium powinno być Ready, kube-proxy Pod NIE istnieje (Cilium go zastępuje)
```

## Część 4 — Join pozostałych 2 CP node'ów

Na cpnode2 (10.135.0.7):
```bash
ssh user@10.135.0.7

# hostname + /etc/hosts (jak w Części 2)
sudo hostnamectl set-hostname cpnode2
# ... kopia /etc/hosts ...

# KLUCZOWE: skopiuj static pod manifest kube-vip (kubeadm join tego nie robi!)
sudo mkdir -p /etc/kubernetes/manifests
scp cpnode1:/etc/kubernetes/manifests/kube-vip.yaml /tmp/
sudo cp /tmp/kube-vip.yaml /etc/kubernetes/manifests/

# Skopiuj też audit/encryption files
scp cpnode1:/etc/kubernetes/audit-policy.yaml /tmp/
scp cpnode1:/etc/kubernetes/enc.yaml /tmp/
sudo cp /tmp/audit-policy.yaml /tmp/enc.yaml /etc/kubernetes/

# Join jako CP (użyj komendy z wyjścia kubeadm init na cpnode1)
sudo kubeadm join kubeapi.example.com:6443 \
  --token <your-token> \
  --discovery-token-ca-cert-hash sha256:<your-hash> \
  --control-plane --certificate-key <your-cert-key>
```

Powtórz dla cpnode3 (10.135.0.3).

## Część 5 — Join 3 worker nodów

Na każdym z knode1/2/3 (10.135.0.2, 10.135.0.6, 10.135.0.4):
```bash
# hostname + /etc/hosts
# Brak kube-vip dla worker (tylko CP potrzebuje)
sudo kubeadm join kubeapi.example.com:6443 \
  --token <your-token> \
  --discovery-token-ca-cert-hash sha256:<your-hash>
```

## Część 6 — Weryfikacja

Z cpnode1:
```bash
kubectl get nodes -o wide
# 6 node, wszystkie Ready, Cilium CNI version

kubectl get pods -n kube-system
# etcd-cpnode{1,2,3}, kube-apiserver-cpnode{1,2,3}, kube-controller-manager, kube-scheduler, kube-vip-cpnode{1,2,3}
# cilium-operator-xxx, cilium-agent (DS na każdym node)
# NO kube-proxy (Cilium zastępuje)

cilium status
kubectl get leases -n kube-system plndr-cp-lock -o jsonpath='{.spec.holderIdentity}'
# aktualny leader kube-vip (np. cpnode1)
```

## Część 7 — Failover test

```bash
# Wyłącz VM aktualnego leadera kube-vip
LEADER=$(kubectl get leases -n kube-system plndr-cp-lock -o jsonpath='{.spec.holderIdentity}')
echo "Leader był: $LEADER — wyłączam..."

# Np. via multipass:
multipass stop $LEADER
# Albo: ssh $LEADER sudo shutdown -h now

# Z laptopa (kubeapi.example.com → VIP):
kubectl get nodes
# Powinno nadal działać (po kilku sekundach VIP przenosi się na inny CP)

kubectl get leases -n kube-system plndr-cp-lock -o jsonpath='{.spec.holderIdentity}'
# nowy leader (np. cpnode2)
```

## Część 8 — Bonus: Gateway API zamiast Ingress

Zgodnie z resztą training używamy **Envoy Gateway** (D2/07), nie NGINX Ingress:

```bash
# Envoy Gateway (stable z Docker Hub OCI)
helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.7.2 \
  -n envoy-gateway-system --create-namespace

kubectl -n envoy-gateway-system rollout status deploy/envoy-gateway --timeout=120s

# cert-manager
helm repo add jetstack https://charts.jetstack.io && helm repo update
helm upgrade --install cert-manager jetstack/cert-manager \
  -n cert-manager --create-namespace \
  --set crds.enabled=true
```

Potem test demonstracji z D2/07 na tym prawdziwym klastrze.

## Część 9 — Cleanup

```bash
# multipass:
for n in cpnode{1,2,3} knode{1,2,3}; do multipass delete $n; done
multipass purge

# DigitalOcean Terraform:
cd terraform/ && terraform destroy \
  -var="do_token=$DO_TOKEN" \
  -var="ssh_key_name=<twoja-nazwa-klucza-ssh-w-DO>"
```

## Pytania

1. **Dlaczego kube-vip jako static pod, nie DaemonSet**? (Hint: kolejność startu.)
2. **Cilium kube-proxy replacement** — jakie zyski? (Hint: eBPF vs iptables, XDP, socket-LB.)
3. **`--skip-phases=addon/kube-proxy`** — co się stanie jeśli pominęsz tę flagę? (Hint: konflikt z Cilium.)
4. **podSubnet /24 vs /16** — ile nodów pomieścisz w każdym?
5. **Audit policy + encryption-at-rest** — co to dokładnie chroni?
6. **etcd stacked vs external** — kiedy warto external?
