# 03 — kubeadm walkthrough: 3 CP + 3 worker + kube-vip (HA) + Cilium CNI

## Cel
Postawić produkcyjny HA Kubernetes klaster **od zera** przy użyciu `kubeadm` na 6 wirtualkach (3 control-plane + 3 worker), z **kube-vip** jako wirtualnym LB dla API server i **Cilium** jako CNI (bez kube-proxy).

## ⚠️ Zakres

To ćwiczenie **NIE DZIAŁA na K3d / Kind / K3s** — te dystrybucje mają już gotowe control-plane (nie kubeadm). Ćwiczenie wymaga **6 osobnych Linux VM** (Ubuntu 22.04 / 24.04 zalecane).

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

- **kube-vip jako static pod** (NIE DaemonSet) — standardowa metoda 2026. Start PRZED `kubeadm init` = VIP gotowy gdy apiserver podnosi się. DaemonSet wymaga RBAC i odpala się po kubeadm init.
- **Cilium zastępuje kube-proxy** — `kubeadm init --skip-phases=addon/kube-proxy`. Cilium eBPF to szybsza i bardziej feature-rich implementacja.
- **podSubnet /16** (nie /24) — minimum dla HA klastra (256 × /24 subnets per node).
- **etcd stacked** (domyślnie kubeadm) — etcd na CP nodach. Dla 500+ nodes klaster rozważ **external etcd**.

## Pliki w katalogu

| Plik | Rola |
|---|---|
| `hosts` | Kopia `/etc/hosts` — mapowanie IP ↔ hostname dla 6 node + VIP. Wrzuć na każdy node. |
| `kubeadm-config.yaml` | Config dla `kubeadm init` — k8s v1.34, podSubnet /16, audit, encryption |
| `kube-vip-static-pod.yaml` | Manifest static pod kube-vip (v1.0.4) — edytuj VIP_IF i address |
| `prepare.sh` | Skrypt setup node-a (containerd + k8s 1.34 packages + sysctl) |
| `kubernetes/audit-policy.yaml` | K8s audit policy (per-pod events) |
| `kubernetes/enc.yaml` | Encryption-at-rest dla etcd Secrets |
| `terraform/` | Opcjonalny provisioning na DigitalOcean (6 droplets) |

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
   terraform apply -var="do_token=$DO_TOKEN"
   ```

4. **Weryfikacja**:
   ```bash
   # Na cpnode1 po pełnym installu:
   kubectl get nodes
   # NAME      STATUS   ROLES           VERSION
   # cpnode1   Ready    control-plane   v1.34.0
   # cpnode2   Ready    control-plane   v1.34.0
   # cpnode3   Ready    control-plane   v1.34.0
   # knode1    Ready    <none>          v1.34.0
   # knode2    Ready    <none>          v1.34.0
   # knode3    Ready    <none>          v1.34.0

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
