# 12 — Namespaces (wirtualne przestrzenie)

## Cel
Zrozumieć czym są namespaces, jak dzielić zasoby między teamy/aplikacje i jak ustawić default namespace dla `kubectl`.

## Kontekst
**Namespace** = wirtualny klaster w klastrze. Pozwala:
- Izolować zasoby per zespół / aplikacja / środowisko
- Stosować RBAC per namespace (D2/06_auth)
- Stosować ResourceQuota per namespace (D3/02_QoS/03)
- Stosować NetworkPolicy per namespace (D3/08)

**Co jest namespaced**: Pods, Services, Deployments, ConfigMaps, Secrets, Roles, ServiceAccounts, …
**Co NIE jest namespaced**: Nodes, PersistentVolumes, ClusterRoles, StorageClasses, …

Domyślne namespaces: `default`, `kube-system`, `kube-public`, `kube-node-lease`.

## Prereqs
- K3d/Kind cluster

## Zadanie

1. Lista namespaces:
   ```bash
   kubectl get namespaces
   ```

2. Stwórz nowy:
   ```bash
   kubectl create namespace workshops
   ```

3. Wdroż coś w nowym namespace:
   ```bash
   kubectl apply -f . -n workshops          # `.` = wszystko z bieżącego katalogu
   kubectl get all -n workshops
   ```

4. **Praktyczny task**: stwórz `python-app` deployment w namespace `workshops`. Znajdź wszystkie obiekty w tym namespace.

5. Ustaw default namespace dla bieżącego context (żeby nie pisać `-n workshops` co chwila):
   ```bash
   kubectl config set-context --current --namespace=workshops
   kubectl get pods                          # już w workshops
   kubectl config set-context --current --namespace=default
   ```

   Łatwiejsze (na slajdach o narzędziach): [`kubens`](https://github.com/ahmetb/kubectx).

6. Listy zasobów cross-namespace:
   ```bash
   kubectl get pods -A                       # all namespaces
   ```

## Pytania kontrolne
1. Czy dwa Pod-y o tej samej nazwie mogą istnieć w dwóch różnych namespace?
2. Czy Service w namespace `A` może rozmawiać z Pod w namespace `B`? (Hint: full DNS)
3. Co się stanie gdy usuniesz namespace zawierający 100 Podów?
4. Dlaczego StorageClass NIE jest namespaced?

## Linki
- [Namespaces docs](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)
- Powershell prompt: [Powerlevel10k zsh](https://github.com/romkatv/powerlevel10k)
- [kube-ps1](https://github.com/jonmosco/kube-ps1) — pokazuje aktualny context i namespace w prompt
