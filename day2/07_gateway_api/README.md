# 07 — Gateway API + cert-manager (Envoy Gateway)

## Cel
Wystawić aplikacje przez **Gateway API** (Envoy Gateway) — najpierw routing po **URI**, potem po **nazwie domeny** (przez nip.io), na końcu dorzucić **TLS** z cert-manager.

## Kontekst
**Gateway API** (GA od K8s 1.29) zastępuje legacy Ingress. Główne różnice:
- **role-oriented model**: trzy CRD-y, trzy role:
  - `GatewayClass` — definiuje implementację (Envoy, NGINX, Cilium, …) — *infra admin*
  - `Gateway` — instancja LB z portami i listenerami — *cluster operator*
  - `HTTPRoute` (lub `TCPRoute`, `GRPCRoute`) — reguły routing — *app dev*
- **typed routes**: HTTPRoute, TCPRoute, TLSRoute, GRPCRoute — nie tylko HTTP
- **portable**: ten sam manifest działa z Envoy Gateway, NGINX Gateway Fabric, Cilium, Istio
- **expressive**: header / method / queryParam matching out-of-the-box, bez annotation hell

W tym ćwiczeniu używamy **Envoy Gateway** (zainstalowany przez `setup-cluster.sh`) i **nip.io** dla nazw domenowych (każda subdomena typu `<dowolna>.127-0-0-1.nip.io` rozwiązuje się na `127.0.0.1` — nie wymaga zmian w `/etc/hosts`).

## Prereqs
- K3d cluster z `setup-cluster.sh` (Envoy Gateway już zainstalowany)
- Aplikacja Python+Redis z **D1/10** (Python Service `python-service` na porcie 5002)

## Sprawdź instalację

```bash
kubectl get pods -n envoy-gateway-system
kubectl get gatewayclass    # powinien być "eg" (envoy gateway)
```

---

## Przykład 1 — Routing po URI (path)

Jeden Gateway, jeden hostname, **routing po prefixie ścieżki**:
- `demo.127-0-0-1.nip.io/` → demo nginx (`app.yaml`)
- `demo.127-0-0-1.nip.io/api` → Python z D1/10 (`python-service:5002`)

```bash
# Demo nginx (drugi backend obok Pythona)
kubectl apply -f app.yaml

# Gateway tylko HTTP:80 (bez TLS na razie)
kubectl apply -f gateway.yaml

# Routing po URI
kubectl apply -f httproute-uri.yaml
```

Test:
```bash
curl http://demo.127-0-0-1.nip.io/             # → nginx welcome
curl http://demo.127-0-0-1.nip.io/api/v1/info  # → odpowiedź Python (licznik z Redis)
```

> **Co tu robi Gateway API:** Envoy patrzy na `Host` header i `path`, dopasowuje regułę z HTTPRoute, kieruje do odpowiedniego Service. Bez annotation hell, deklaratywnie.

---

## Przykład 2 — Routing po nazwie domeny (nip.io)

Ta sama Gateway, **dwa różne HTTPRoute z różnymi `hostnames`**:
- `python.127-0-0-1.nip.io` → Python (D1/10)
- `nginx.127-0-0-1.nip.io` → demo nginx

```bash
# Usuń route URI (lub zostaw — będą działać równolegle)
kubectl delete -f httproute-uri.yaml

# Routing per-domain
kubectl apply -f httproute-domain.yaml
```

Test:
```bash
curl http://python.127-0-0-1.nip.io/api/v1/info
curl http://nginx.127-0-0-1.nip.io/
```

> **Dlaczego nip.io:** każdy `<cokolwiek>.A-B-C-D.nip.io` rozwiązuje się na IP `A.B.C.D` (tutaj `127.0.0.1`). Idealny do lokalnego demo bez DNS / `/etc/hosts`.

---

## Przykład 3 — TLS przez cert-manager (Let's Encrypt staging)

Dorzucamy listener HTTPS:443 do Gateway, certyfikat zarządzany przez cert-manager.

```bash
# cert-manager już z setup-cluster.sh
kubectl get pods -n cert-manager

# ClusterIssuer (Let's Encrypt staging — fake CA "Pretend Pear X1")
kubectl apply -f cluster-issuer-letsencrypt.yaml

# Edytuj certificate.yaml — wpisz swoją nip.io domenę (np. python.<TWOJ-PUBLICZNY-IP>.nip.io)
kubectl apply -f certificate.yaml
kubectl describe certificate app-tls   # śledź sekcję "Events"

# Gateway z listenerem HTTPS (gateway.yaml już zawiera oba listenery — HTTP i HTTPS)
```

Test:
```bash
curl -k https://python.<TWOJ-IP>.nip.io/api/v1/info
# -k bo Let's Encrypt staging używa fake-CA
```

> **Uwaga:** HTTP-01 challenge wymaga, żeby Let's Encrypt mógł dotrzeć do Twojego IP od strony internetu. Lokalnie z 127.0.0.1 to **nie zadziała** — potrzebny publiczny IP (np. przez `cloudflared tunnel`, `ngrok`) lub przejście na **DNS-01** (wymaga API providera DNS). Dla czystej nauki cert-managera w lokalnym K3d alternatywą jest `selfSigned` ClusterIssuer.

## Linki
- [Gateway API spec](https://gateway-api.sigs.k8s.io/)
- [Envoy Gateway docs](https://gateway.envoyproxy.io/)
- [cert-manager docs](https://cert-manager.io/docs/)
- [nip.io — wildcard DNS](https://nip.io/)
- [ingress2gateway migration tool](https://github.com/kubernetes-sigs/ingress2gateway)
