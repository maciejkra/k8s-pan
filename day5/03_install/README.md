# 03 — kubeadm walkthrough: 3 CP + 3 worker + kube-vip (HA) + Cilium CNI

## Cel
Postawić produkcyjny HA Kubernetes klaster **od zera** przy użyciu `kubeadm` na 6 wirtualkach (3 control-plane + 3 worker), z **kube-vip** jako wirtualnym LB dla API server i **Cilium** jako CNI (bez kube-proxy).

## ⚠️ Zakres

To ćwiczenie **NIE DZIAŁA na K3d / Kind / K3s** — te dystrybucje mają już gotowe control-plane (nie kubeadm). Ćwiczenie wymaga **6 osobnych Linux VM** (Ubuntu 24.04 LTS).

Opcje infrastruktury:
- **DigitalOcean / AWS / GCP**: 6 droplet/instance z Terraform (patrz `terraform/`).
- **Multipass**: `multipass launch -n cpnode1 -c 2 -m 4G` × 6 (Mac/Linux).
- **Vagrant**: VirtualBox/VMware VM-y (wolniejsze, ale darmowe).
- **Bare-metal lab**: 6 Raspberry Pi / NUC (najbliższe prod).

Minimum per VM: 2 CPU, 2 GB RAM, 20 GB disk.

## Architektura

```
                        [ kubeapi.example.com → VIP 10.135.0.100 ]
                                         ↑
                        kube-vip leader election (Raft)
                                         |
          +--------------+---------------+---------------+
          |                              |                           |
  cpnode1 (10.135.0.5)         cpnode2 (10.135.0.7)     cpnode3 (10.135.0.3)
     kube-apiserver                kube-apiserver            kube-apiserver
     etcd                          etcd                      etcd
     controller-manager            controller-manager        controller-manager
     scheduler                     scheduler                 scheduler
     kube-vip (static pod)         kube-vip (static pod)     kube-vip (static pod)
          |                              |                           |
  ========|==============================|===========================|=========
                        Cilium CNI (kube-proxy replacement, eBPF)
  ========|==============================|===========================|=========
          |                              |                           |
  knode1 (10.135.0.2)          knode2 (10.135.0.6)       knode3 (10.135.0.4)
     kubelet                       kubelet                   kubelet
     containerd                    containerd                containerd
     Cilium agent                  Cilium agent              Cilium agent
```

### Kluczowe decyzje

- **kube-vip jako static pod** (NIE DaemonSet) — kanoniczna metoda dla kubeadm wg [docs kube-vip](https://kube-vip.io/docs/installation/static/). Start PRZED `kubeadm init` = VIP gotowy gdy apiserver podnosi się. DaemonSet wymaga RBAC i odpala się po kubeadm init.
- **Cilium zastępuje kube-proxy** — `kubeadm init --skip-phases=addon/kube-proxy`. Cilium eBPF to szybsza i bardziej feature-rich implementacja.
- **podSubnet /16** (nie /24) — minimum dla HA klastra (256 × /24 subnets per node).
- **etcd stacked** (domyślnie kubeadm) — etcd na CP nodach. Dla 500+ nodes klaster rozważ **external etcd**.

### Endpoint klastra na DigitalOcean

DigitalOcean VPC blokuje gratuitous ARP, więc `kube-vip` w trybie ARP **nie programuje routingu** między dropletami — pod startuje, leader election działa (`Lease plndr-cp-lock`), ale ruch przez VIP nie chodzi. Na DO używamy **DigitalOcean Load Balancera** (TCP passthrough na :6443) jako rzeczywistego `controlPlaneEndpoint`, a kube-vip pokazujemy dydaktycznie. Terraform tworzy oba.

Praktycznie: w `/etc/hosts` na każdym node `kubeapi.example.com` celuje w **publiczny IP DO LB** (`terraform output control_plane_lb_ip`), nie w `10.135.0.100`. Reszta pipeline'u (Cilium, Gateway API, kubeadm join) jest identyczna jak na bare-metal.

## Pliki w katalogu

| Plik | Rola |
|---|---|
| `hosts` | Kopia `/etc/hosts` — mapowanie IP ↔ hostname dla 6 node + `kubeapi.example.com`. Generowany przez Terraform; wrzuć na każdy node. |
| `kubeadm-config.yaml` | Config dla `kubeadm init` — k8s v1.35.3, podSubnet /16, audit, encryption |
| `kube-vip-static-pod.yaml` | Manifest static pod kube-vip (v1.1.2) — edytuj `vip_interface` i `address` |
| `prepare.sh` | Skrypt setup node-a (containerd + k8s 1.35 packages + sysctl + enable kubelet) |
| `kubernetes/audit-policy.yaml` | K8s audit policy (per-pod events) |
| `kubernetes/enc.yaml` | Encryption-at-rest dla etcd Secrets — wygeneruj klucz przed użyciem (instrukcja w `task.md` Część 0) |
| `terraform/` | Opcjonalny provisioning na DigitalOcean (6 droplets + LB + VPC) |

### Co robi Terraform vs co robisz Ty

Po `terraform apply` (DO path) masz GOTOWE:

| | Terraform | Ty |
|---|---|---|
| 6 dropletów Ubuntu 24.04 (3 CP, 3 worker) | ✅ | — |
| DigitalOcean Load Balancer (TCP 6443 → CP) | ✅ | — |
| Hostname dropletów (`cpnode1`, `knode1`, …) | ✅ DO ustawia automatycznie | — |
| `/etc/hosts` na każdym node (6 IP + `kubeapi.example.com` → IP LB) | ✅ | — |
| `prepare.sh` skopiowany i wykonany na każdym node | ✅ | — |
| `kubeadm-config.yaml` + `kube-vip-static-pod.yaml` w `/root/` na CP | ✅ skopiowane | edytujesz `advertiseAddress`, `certSANs`, `vip_interface` przed `kubeadm init` |
| `audit-policy.yaml` + `enc.yaml` w `/etc/kubernetes/` na CP | ✅ skopiowane | klucz `enc.yaml` generujesz LOKALNIE przed `terraform apply` (Część 0) |
| Wszystko od `kubeadm init` w dół | — | wykonujesz wg `task.md` Części 2–9 |

## Zadanie

Patrz [`task.md`](./task.md).

## Testing approaches

**Jak przetestować że ten walkthrough działa?** Maciek sugeruje:

1. **Multipass (szybkie, Mac/Linux)** — ~5 minut setup:
   ```bash
   for name in cpnode{1,2,3} knode{1,2,3}; do
     multipass launch -n $name -c 2 -m 4G --disk 20G 24.04
   done
   # Następnie po `multipass shell cpnode1` odpalasz prepare.sh + kubeadm init
   ```

2. **Vagrant (Linux/Windows)**:
   ```bash
   # Vagrantfile z 6 box-ami ubuntu/jammy64
   vagrant up --provider=virtualbox
   ```

3. **DigitalOcean przez Terraform** (~$30 za 24h testu):
   ```bash
   cd terraform/
   terraform init
   terraform apply \
     -var="do_token=$DO_TOKEN" \
     -var="ssh_key_name=<twoja-nazwa-klucza-SSH-w-DO>"
   # Po apply:
   terraform output control_plane_lb_ip   # → kubeapi.example.com
   terraform output cpnode_private_ips    # → certSANs / /etc/hosts
   ```

4. **Weryfikacja**:
   ```bash
   # Na cpnode1 po pełnym installu:
   kubectl get nodes
   # NAME      STATUS   ROLES           VERSION
   # cpnode1   Ready    control-plane   v1.35.3
   # cpnode2   Ready    control-plane   v1.35.3
   # cpnode3   Ready    control-plane   v1.35.3
   # knode1    Ready    <none>          v1.35.3
   # knode2    Ready    <none>          v1.35.3
   # knode3    Ready    <none>          v1.35.3

   # Cilium health
   cilium status --wait
   # kube-vip leader
   kubectl get leases -n kube-system plndr-cp-lock

   # Failover test — wyłącz leadership cpnode
   multipass stop $(kubectl get leases -n kube-system plndr-cp-lock -o jsonpath='{.spec.holderIdentity}')
   # kubectl cały czas działa (VIP przepadł na kolejny CP)
   ```

## Linki
- [kubeadm install (oficjalne)](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
- [kube-vip docs](https://kube-vip.io/)
- [kube-vip static pod guide](https://kube-vip.io/docs/installation/static/)
- [Cilium install](https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/)
- [Cilium kube-proxy replacement](https://docs.cilium.io/en/stable/network/kubernetes/kubeproxy-free/)
- [kubeadm-config v1beta4 spec](https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta4/)
