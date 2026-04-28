# Zadanie — manualna instalacja klastra (3 CP + 3 worker + kube-vip + Cilium)

## Część 0 — Przygotuj infrastrukturę

Uruchom 6 VM (Ubuntu 24.04) z przynajmniej 2 CPU, 2 GB RAM, 20 GB disk. Zobacz README sekcję "Testing approaches".

Zweryfikuj że node'y widzą się wzajemnie (to samo private network / VPC):
```bash
# Na cpnode1:
ping -c 2 10.135.0.7    # cpnode2
ping -c 2 10.135.0.2    # knode1
```

**Klucz szyfrujący Secrets** (`enc.yaml`):
- **DO**: Terraform generuje losowo per `terraform apply` (`random_bytes` provider) i wstrzykuje przez templatefile — nic nie robisz.
- **Bare-metal**: `kubernetes/enc.yaml` ma placeholder `REPLACE_ME_BASE64_32B`. Wygeneruj i podstaw:
  ```bash
  NEW_KEY=$(head -c 32 /dev/urandom | base64)
  sed -i.bak "s|REPLACE_ME_BASE64_32B|${NEW_KEY}|" kubernetes/enc.yaml
  ```

## Część 1 — Przygotuj KAŻDY z 6 node'ów

`prepare.sh` instaluje: containerd, kubeadm/kubelet/kubectl v1.35.3, sysctl (forwarding, bridge-nf), disable swap, enable kubelet. Plus na DO: cloud-init wait + masking unattended-upgrades (rozwiązuje race apt lock).

- **DO**: Terraform odpala `prepare.sh` na każdym z 6 dropletów automatycznie podczas `terraform apply`. Skip do Część 2.
- **Bare-metal**:
  ```bash
  # Na każdym z 6 node'ów:
  scp prepare.sh user@<ip>:/tmp/
  ssh user@<ip>
  chmod +x /tmp/prepare.sh && sudo /tmp/prepare.sh
  ```

## Część 2 — Setup pierwszego CP node (cpnode1)

### 2.1 — kube-vip jako STATIC POD (PRZED `kubeadm init`)

**Po co**: kube-vip zapewnia HA dla apiservera. Wszystkie 3 CP biorą udział w **leader election** (Raft) na `Lease plndr-cp-lock`; aktywny leader programuje VIP (`10.135.0.100`) na swoim interfejsie. Padnie leader → kube-vip na innym CP w ciągu kilku sekund przejmuje VIP. `kubectl` z laptopa do `kubeapi.example.com:6443` (= VIP) ciągle działa.

**Dlaczego static pod a nie DaemonSet**: kubelet czyta `/etc/kubernetes/manifests/` przy starcie node'a — kube-vip wstaje **przed** apiserverem, VIP gotowy gdy apiserver woła sam siebie. DaemonSet wymagałby działającego apiservera = chicken-and-egg.

**Specyfika DO**: VPC blokuje gratuitous ARP (GARP), więc VIP `10.135.0.100` na DO **nie jest realnie osiągalny** między dropletami — leader election działa (przez API), ale ruch idzie przez DigitalOcean LB (`controlPlaneEndpoint: kubeapi.example.com:6443` → IP DO LB → losowy CP). Kube-vip zostaje dydaktycznie. Bare-metal/Multipass: VIP działa naturalnie.

**Plik**: `kube-vip-static-pod.yaml` (image `ghcr.io/kube-vip/kube-vip:v1.1.2`). Kluczowe pola: `vip_interface` (eth0 na DO Ubuntu 24.04), `address` (`10.135.0.100`), `cp_enable=true` + `vip_leaderelection=true`.

**DO** — Terraform już:
- wyrenderował `kube-vip-static-pod.yaml.tpl` z `vip_interface=eth0`, `address=10.135.0.100`,
- wrzucił go do `/etc/kubernetes/manifests/kube-vip.yaml` na **każdym** CP (cpnode1/2/3).

**Bare-metal/Multipass** — ręcznie PRZED `kubeadm init`:
```bash
# Edytuj kube-vip-static-pod.yaml:
#   vip_interface: eth0   # albo eth1/ens3 — `ip a` pokaże nazwy
#   address: 10.135.0.100  # twój VIP
sudo mkdir -p /etc/kubernetes/manifests
sudo cp kube-vip-static-pod.yaml /etc/kubernetes/manifests/kube-vip.yaml
```

### 2.2 — kubeadm init na cpnode1

Na DO Terraform również ułożył: hostname, `/etc/hosts`, `/etc/kubernetes/{audit-policy,enc}.yaml`, `/root/kubeadm-config.yaml` z `advertiseAddress` = real VPC IP + `certSANs` z publicznymi CP IP + LB IP.

```bash
ssh root@<cpnode1-public-ip>     # `terraform output cpnode_ips` → pierwszy

# (opcjonalnie zweryfikuj że Terraform poprawnie ustawił):
grep advertiseAddress /root/kubeadm-config.yaml   # → real prywatny IP (np. 10.20.0.X)
ls /etc/kubernetes/manifests/                     # → kube-vip.yaml
cat /etc/hosts                                    # → 6 node + kubeapi.example.com

# Init klastra (Cilium zastępuje kube-proxy — skip faze)
sudo kubeadm init --config /root/kubeadm-config.yaml --upload-certs \
  --skip-phases=addon/kube-proxy

# ⚠️ ZACHOWAJ wyjście — są tam 2 komendy kubeadm join (dla CP i worker)!
# Cert-key (--certificate-key) WYGASA po 2h. Jeśli przeciągniesz, regeneruj:
#   sudo kubeadm init phase upload-certs --upload-certs
```

**Bare-metal** dodatkowo PRZED `kubeadm init`:
- `sudo hostnamectl set-hostname cpnode1`
- Wklej `/etc/hosts` z pliku `./hosts` (podstaw realne IP swoich VM)
- `sudo ip a a dev <iface> 10.135.0.100/32` — tymczasowy VIP (na DO bez sensu, VPC blokuje GARP)
- Edytuj `kubeadm-config.yaml`: `advertiseAddress` → IP cpnode1, `certSANs` → realne IP swoich CP

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

Na DO Terraform już ułożył pliki na cpnode2/3 (kube-vip manifest, audit-policy, enc.yaml, kubeadm-config) oraz `/root/private_ip` z prywatnym VPC IP node'a.

**Ważne**: `--apiserver-advertise-address=$(cat /root/private_ip)` jest **wymagana** na DO. Bez niej kubeadm wybierze publiczny IP (default route eth0), apiserver i etcd peer staną na publicznym IP, etcd peer cert pokryje tylko publiczny — `kubeadm join` zawiśnie na `etcdserver: can only promote a learner member which is in sync with leader`.

```bash
ssh root@<cpnode2-public-ip>

# Join jako CP (komenda z wyjścia `kubeadm init` na cpnode1, z dodanym --apiserver-advertise-address)
sudo kubeadm join kubeapi.example.com:6443 \
  --token <your-token> \
  --discovery-token-ca-cert-hash sha256:<your-hash> \
  --control-plane --certificate-key <your-cert-key> \
  --apiserver-advertise-address=$(cat /root/private_ip)
```

Powtórz dla cpnode3.

**Bare-metal** dodatkowo PRZED `kubeadm join`:
- hostname + `/etc/hosts` jak w Części 2
- `scp cpnode1:/etc/kubernetes/manifests/kube-vip.yaml /etc/kubernetes/manifests/`
- `scp cpnode1:/etc/kubernetes/audit-policy.yaml cpnode1:/etc/kubernetes/enc.yaml /etc/kubernetes/`
- `--apiserver-advertise-address` można pominąć jeśli VM ma single NIC z prywatnym IP

### Recovery jeśli cpnode2 zawisa na "learner not in sync"

To znak że cpnode2 join wybrał publiczny IP. Cleanup + retry z flagą:

```bash
# Na cpnode2 — reset stanu kubeadm:
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes/pki /etc/kubernetes/manifests/etcd.yaml \
            /etc/kubernetes/manifests/kube-apiserver.yaml \
            /etc/kubernetes/manifests/kube-controller-manager.yaml \
            /etc/kubernetes/manifests/kube-scheduler.yaml

# Na cpnode1 — usuń stale etcd member learner:
ETCD_POD=$(kubectl -n kube-system get pod -l component=etcd -o jsonpath='{.items[0].metadata.name}')
kubectl -n kube-system exec $ETCD_POD -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  member list
# Skopiuj ID cpnode2, potem:
kubectl -n kube-system exec $ETCD_POD -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  member remove <cpnode2-id>

# Z powrotem na cpnode2 — retry z flagą.
# Jeśli minęły >2h od init: regeneruj cert-key na cpnode1: `kubeadm init phase upload-certs --upload-certs`
```

## Część 5 — Join 3 worker nodów

Worker nie potrzebuje kube-vip, audit ani enc.yaml. Tylko join:
```bash
ssh root@<knode1-public-ip>
sudo kubeadm join kubeapi.example.com:6443 \
  --token <your-token> \
  --discovery-token-ca-cert-hash sha256:<your-hash>
```

Powtórz dla knode2, knode3.

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

# DO: ssh root@<public-ip-LEADERa> sudo shutdown -h now
# Multipass: multipass stop $LEADER

# Z laptopa (kubeapi.example.com → VIP / DO LB):
kubectl get nodes
# Powinno działać po kilkunastu sekundach (DO LB health-check 5s × 3, lub VIP failover na bare-metal)

kubectl get leases -n kube-system plndr-cp-lock -o jsonpath='{.spec.holderIdentity}'
# nowy leader (np. cpnode2)
```

## Część 8 — Bonus: Gateway API zamiast Ingress

Zgodnie z resztą training używamy **Envoy Gateway** (D2/07), nie NGINX Ingress:

```bash
# Envoy Gateway controller (stable z Docker Hub OCI)
helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.7.2 \
  -n envoy-gateway-system --create-namespace

kubectl -n envoy-gateway-system rollout status deploy/envoy-gateway --timeout=120s

# DO-specific: Envoy data plane jako DaemonSet na każdym CP w hostNetwork.
# Bez tego data plane = Deployment + Service:LoadBalancer pending (kubeadm bez
# cloud-controllera). Z DaemonSet bind hostport 80/443 → DO LB control_plane_lb
# (z terraform; rules 80/443 → tag control-plane) trafia bezpośrednio.
# Plik nadpisuje też GatewayClass `eg` z parametersRef.
kubectl apply -f envoy-proxy.yaml
kubectl -n envoy-gateway-system rollout status ds -l gateway.envoyproxy.io/owning-gatewayclass=eg --timeout=120s 2>/dev/null || true

# cert-manager
helm repo add jetstack https://charts.jetstack.io && helm repo update
helm upgrade --install cert-manager jetstack/cert-manager \
  -n cert-manager --create-namespace \
  --set crds.enabled=true
```

**Test po Bonus**: gdy zaaplikujesz Gateway resource (np. z D2/07: `kubectl apply -f day2/07_gateway_api/gateway-http.yaml`), `curl http://$(terraform -chdir=terraform output -raw control_plane_lb_ip)` trafi przez DO LB → CP host:80 → Envoy proxy → HTTPRoute backend.

**Uwaga**: `day2/07_gateway_api/gateway-http.yaml` zawiera `GatewayClass eg` bez `parametersRef`. Jego `kubectl apply` **nadpisuje** override z `envoy-proxy.yaml` → Envoy wraca do default Deployment na worker. Re-apply: `kubectl apply -f envoy-proxy.yaml`. Idempotentne.

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
