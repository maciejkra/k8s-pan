# Zadanie - manualna instalacja klastra (3 CP + 3 worker + LB)

Twoim zadaniem jest postawić klaster K8s **od zera** za pomocą `kubeadm` na 6 wirtualkach (3 control-plane + 3 worker), używając **kube-vip** jako wirtualnego LB do API serwera.

1. Na każdym z 6 node'ów uruchom `prepare.sh` (przygotowuje system do `kubeadm`).
2. Na pierwszym CP node ustaw hostname, podpiętrzony VIP, plik `/etc/hosts`, popraw `kubeadm-config.yaml` (`advertiseAddress`, `certSANs`) i wykonaj `kubeadm init --config ./kubeadm-config.yaml --upload-certs`. **Zachowaj komendy `kubeadm join`**.
3. Zainstaluj **Cilium** jako CNI (`cilium install --version 1.17.6`).
4. Dołącz pozostałe 2 CP node'y (`kubeadm join --control-plane --certificate-key ...`) oraz 3 worker node'y.
5. Uruchom `kube-vip.sh` na jednym CP node (najpierw zaktualizuj `VIP_IF` i `VIP_IP`). Zweryfikuj failover - wyłącz CP, na którym był VIP, i sprawdź, czy API odpowiada.
6. **Bonus**: zainstaluj `ingress-nginx` jako DaemonSet z `hostNetwork: true` na CP node'ach.
