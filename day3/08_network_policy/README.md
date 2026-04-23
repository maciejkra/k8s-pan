# 08 — Network Policy: izolacja sieciowa

> ## ⚠️ WAŻNE — wymagane CNI z policy support
>
> **Domyślny CNI K3s jest Flannel, który NIE wspiera NetworkPolicy.** Zaaplikowane manifesty pokażą `Created`, ale policy będą **no-op** — cały ruch nadal przechodzi. Student zobaczy "wszystko działa" i wyciągnie złe wnioski.
>
> ### K3s / K3d
>
> Przy tworzeniu klastra wyłącz Flannel i zainstaluj Calico lub Cilium:
> ```bash
> k3d cluster create training \
>   --k3s-arg '--flannel-backend=none@server:*' \
>   --k3s-arg '--disable-network-policy=false@server:*' \
>   --agents 2 --port "80:80@loadbalancer" --port "443:443@loadbalancer"
>
> # Potem install Cilium
> cilium install --version 1.17.6
> cilium status --wait
> ```
>
> ### Kind
>
> Domyślny **kindnet** (od v0.20+) wspiera NetworkPolicy dla **ingress**; od v0.26+ również **egress**. Sprawdź wersję:
> ```bash
> kind --version
> ```
> Alternatywnie Kind z Cilium:
> ```yaml
> # kind.config.yaml
> networking:
>   disableDefaultCNI: true
> ```
> ```bash
> kind create cluster --config kind.config.yaml
> cilium install --version 1.17.6
> ```
>
> Bez tego kroku ćwiczenie nie zadziała.

## Cel
Zaaplikować **default-deny** NetworkPolicy w namespace, dodać selektywne `allow` dla wybranych Pod-ów. Zaobserwować jak ruch jest blokowany i jak **DNS pułapka** łamie pozornie proste policy.

## Kontekst
Domyślnie w K8s **wszystkie Pody mogą rozmawiać ze wszystkimi** — brak izolacji. To wystarczy dla małego klastra, ale w multi-tenant lub prod = security risk.

**NetworkPolicy** = manifest definiujący ingress/egress dla Pod-ów (matched przez `podSelector`). Egzekwowane przez CNI (Calico, Cilium, kindnet ≥0.20, Weave). Flannel nie.

Wzorzec produkcyjny:
1. **default-deny** all ingress (i opcjonalnie egress) per namespace
2. Selektywnie `allow` per komunikacja: `frontend → backend`, `backend → db`, `app → DNS`

Bez `default-deny` wszystkie nowe Pody mają full komunikację — łatwo zapomnieć dodać policy → szczelina security.

## Prereqs
- K3s / Kind / K3d cluster z **CNI obsługującym NetworkPolicy** (patrz banner wyżej!)

## Pliki

| Plik | Co robi |
|---|---|
| `test-pods.yaml` | 2 Pody: `client` (app=busybox) + `server` (app=server, z Service) |
| `deny.network.policy.yaml` | Default-deny — blokuje WSZYSTKO dla wszystkich Pod-ów w NS |
| `allow.network.policy.yaml` | Allow-all — override default-deny (pokazuje composition) |
| `network-policy.yaml` | Egress deny dla busybox |
| `network-policy-dns.yaml` | Egress allow TYLKO do DNS (kube-system/kube-dns) |
| `allow-frontend-backend.yaml` | Ingress allow: tier=frontend → tier=backend |

## Zadanie

Patrz [`task.md`](./task.md).

## Linki
- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Cluster networking](https://kubernetes.io/docs/concepts/cluster-administration/networking/)
- [Network Policy editor](https://editor.networkpolicy.io)
- [Recipes (ahmetb)](https://github.com/ahmetb/kubernetes-network-policy-recipes)
- [Cilium NetworkPolicy vs CiliumNetworkPolicy](https://docs.cilium.io/en/stable/security/policy/)
