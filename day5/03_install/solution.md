# Solution — 03_install

## Odpowiedzi

### Dlaczego kube-vip jako static pod, nie DaemonSet

**Static pod** (plik w `/etc/kubernetes/manifests/kube-vip.yaml`):
1. kubelet widzi manifest przy starcie node-a.
2. kubelet uruchamia Pod **przed** jakimkolwiek połączeniem z apiserver.
3. kube-vip programuje VIP na interface.
4. Dopiero teraz kubeadm init może kontaktować się z apiserver przez VIP.

**DaemonSet** (`kubectl apply -f kube-vip-ds.yaml`):
1. kubeadm init kończy się (bez VIP).
2. Potem `kubectl apply` DaemonSet.
3. Kontroler DS czeka aż apiserver gotowy → pierwszy Pod startuje.
4. Przez ~30s klaster nie ma VIP — problem przy redundancy (jeśli CP-1 padnie w tym czasie, VIP padnie).

Static pod **starszy niż apiserver** → zero chicken-and-egg.

**Ważna pułapka**: `kubeadm join --control-plane` **nie kopiuje static pod manifestów**. Musisz ręcznie `scp` plik na każdy nowy CP node zanim zrobisz join.

### Cilium kube-proxy replacement

**Tradycyjnie** (kube-proxy + iptables):
- Service.Spec: ClusterIP → kube-proxy generuje `iptables` rule (NAT).
- Dla 1000+ Services = 10 000+ iptables rules. Każdy nowy packet tableau przez te rules (liniowo).
- Latency ~100µs per packet.

**Cilium eBPF replacement**:
- Service → Cilium instaluje eBPF program w kernel (`tc` hook albo XDP).
- Routing decyduje w kernelu w O(1) (hash table).
- Latency ~10µs per packet.
- **Socket-LB**: connection load-balanced w kernel socket level zamiast per-packet (jeszcze szybsze dla TCP).

Dodatkowo Cilium bez kube-proxy daje:
- **Hubble observability** — L7 visibility per Pod (HTTP methods, gRPC service names).
- **NetworkPolicy L7** (D3/08).
- **Encryption** (WireGuard, IPsec) — mTLS bez sidecar.
- **Cluster mesh** — multi-cluster networking bez dodatkowego service mesh.

### `--skip-phases=addon/kube-proxy`

Bez tej flagi: kubeadm install domyślnego kube-proxy DaemonSet. Gdy Cilium też instaluje swoje eBPF zamienniki → **conflict**:
- Cilium próbuje obsłużyć Service traffic przez eBPF.
- kube-proxy próbuje przez iptables.
- Pakiety rozdwajają się / Service traffic się zapętla.

Sygnały: `kube-proxy` Pod ciągle w `CrashLoopBackOff` (nie dostaje ruchu), LUB Service time'out na niektórych Pod-ach.

Fix: albo `--skip-phases=addon/kube-proxy` przy init, albo `kubectl delete ds/kube-proxy -n kube-system` po init.

### podSubnet /24 vs /16

`podSubnet: 10.244.0.0/24` = **256 IP total** dla WSZYSTKICH Pod-ów w klastrze.

Kubernetes podziela podSubnet na **per-node block** (default /24 per node). Matematyka:
- /24 cluster-level + /24 per-node = **1 node** się zmieści. Po 2 nodach → scheduling fail.
- /16 cluster-level + /24 per-node = `2^(24-16) = 256` nodów.
- /16 cluster-level + /25 per-node = `2^(25-16) = 512` nodów × 126 Pod-ów = 64k Pod-ów.

Minimum dla HA: **/16**. Standard enterprise: `10.244.0.0/16` lub `192.168.0.0/16`.

### Audit policy + encryption-at-rest

**Audit policy** (`/etc/kubernetes/audit-policy.yaml`):
- apiserver loguje każdy request (kto, co, kiedy) do `/var/log/kubernetes/audit/audit.log`.
- Poziomy: `None`, `Metadata`, `Request`, `RequestResponse`.
- Compliance: SOC2, ISO 27001, PCI-DSS **wymagają** audit trail.
- **Nie chroni**: przed atakiem; tylko forensic/detection po fakcie.

**Encryption-at-rest** (`/etc/kubernetes/enc.yaml`):
- Przed zapisem do etcd: apiserver szyfruje Secret / ConfigMap data.
- Providery: `aesgcm` (default, AES-256-GCM), `kms` (external KMS jak AWS KMS, HashiCorp Vault).
- **Chroni**: przed wyciekiem etcd backupów (ktoś skradł `/var/lib/etcd` dump → nie może odczytać Secrets bez klucza szyfrującego).
- **Nie chroni**: przed kube-apiserver compromise (apiserver ma klucz w RAM).

Produkcja: `kms` provider + klucz w HSM / cloud KMS. Rotacja kluczy co 90 dni.

### etcd stacked vs external

**Stacked** (domyślnie kubeadm):
- etcd Pod na każdym CP node.
- 3 CP = 3 etcd instancje (Raft quorum 2 z 3).
- Plus: prosta instalacja, mniej VM.
- Minus: CP outage = etcd outage. etcd I/O limited CPU/disk CP (heavy etcd load spowalnia apiserver).

**External**:
- Dedicated etcd VM (typowo 3-5 dla HA).
- CP nody łączą się przez `--etcd-servers` flag.
- Plus: niezależne skalowanie, etcd benefits od SSD.
- Plus: CP upgrade bez dotykania etcd (reduce risk).
- Minus: więcej VM, więcej network ops.

Reguła praktyczna:
- **<100 nodów**: stacked (lżejsze operacyjnie).
- **100-500 nodów**: rozważ external (etcd I/O dominuje).
- **>500 nodów**: external + dedicated disks (NVMe).

## Walidacja end-to-end

```bash
# Po pełnym setup (na cpnode1)
kubectl get nodes -o wide
# 6 Ready node

kubectl get pods -n kube-system
# cilium-operator-xxx, cilium-agent-xxx (6 = po jednym na node)
# kube-vip-cpnode{1,2,3}
# etcd-cpnode{1,2,3}, kube-apiserver-cpnode{1,2,3}, kube-controller-manager, kube-scheduler
# coredns-xxx, coredns-xxx
# BRAK kube-proxy (Cilium zastępuje)

cilium status --wait
# Cilium: Ok

# kube-vip leader
kubectl get leases -n kube-system plndr-cp-lock
# holderIdentity: cpnode1 (lub inny aktywny)

# Test endpointa apiservera
curl -sk https://kubeapi.example.com:6443/healthz
# ok
# Bare-metal: kubeapi → VIP kube-vip
# DigitalOcean: kubeapi → publiczny IP DO LB (kube-vip działa tylko jako leader election demo)
```

## Troubleshooting

### `kubeadm init` hangs at "api server health check"

VIP nie działa. Sprawdź:
```bash
# Na cpnode1:
ip a show eth1 | grep 10.135.0.100   # VIP istnieje?
sudo journalctl -u kubelet | tail -50  # błędy kubelet?
sudo crictl ps --state Running | grep kube-vip
```

Często: `vip_interface` w kube-vip-static-pod.yaml pointuje na nieistniejący interface. Edytuj i restart kubelet.

### Nodes join ale status `NotReady`

```bash
kubectl describe node knode1 | grep -A 5 Conditions
# NetworkReady: false — CNI nie zainstalowany (Cilium)
```

Fix: uruchom `cilium install` z cpnode1.

### kube-vip leader election flapping

```bash
kubectl get events -n kube-system --sort-by='.lastTimestamp' | grep plndr
# "acquired lease", "lost lease" co kilka sekund
```

Przyczyna: network partition między CP nodami. Sprawdź `ping` latency między cpnode1/2/3. Jeśli >50ms → problem z siecią VPC.

### `kubeadm join --control-plane` fails: `FileAvailable--etc-kubernetes-manifests-kube-vip.yaml`

Zapomniałeś skopiować kube-vip-static-pod.yaml. Static pod jest wymagany PRZED join (tak jak przy init).

### Na DigitalOcean: VIP nie odpowiada, ale klaster działa

DigitalOcean VPC blokuje gratuitous ARP, więc kube-vip w trybie ARP nie programuje routingu między dropletami. Pod startuje, leader jest wybierany (`kubectl get leases -n kube-system plndr-cp-lock`), ale `curl https://10.135.0.100:6443/healthz` z innego node'a nie odpowiada. To **oczekiwane** — na DO endpoint `kubeapi.example.com` celuje w **DigitalOcean Load Balancer** (TCP passthrough na :6443), nie w VIP. kube-vip pokazujemy dydaktycznie. Failover zapewnia DO LB health-check (interval 5s × healthy_threshold 3 = ~15s do wyłączenia padniętego CP z puli).

## Cross-link

- D2/07 (Gateway API) — wdrażaj w prawdziwym klastrze po instalacji
- D2/06 (AuthN/AuthZ) — RBAC na prawdziwym klastrze
- D3/08 (NetworkPolicy) — Cilium domyślnie wspiera NP
- D4/06 (kube-bench) — odpal kube-bench na tym klastrze; powinien dać ~90% PASS na kubeadm CIS
- D4/03 (Admission Controllers) — VAP + OPA/Gatekeeper na prawdziwym klastrze
- Presentation slajd 60 (kubeadm) — teoretyczny overview
