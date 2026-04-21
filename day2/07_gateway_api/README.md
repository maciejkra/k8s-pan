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
- K3d cluster z `setup-cluster.sh` (Envoy Gateway już zainstalowany — patrz sekcja „Instalacja Envoy Gateway + cert-manager (Helm)" poniżej)
- Aplikacja Python+Redis z **D1/10**. Python Service `python-service` nasłuchuje na **porcie 80** (Service port) — wewnętrznie `targetPort: api` mapuje go na `containerPort: 5002` w podzie. W `HTTPRoute.backendRefs.port` używaj **portu Service** (`80`), nie portu kontenera.

## Instalacja Envoy Gateway + cert-manager (Helm)

> `setup-cluster.sh` instaluje to za Ciebie. Poniższe komendy to dokładnie to, co robi skrypt — warto je znać, żeby zainstalować ręcznie na własnym klastrze (bez `setup-cluster.sh`) albo zmodyfikować wersję/values.

### Envoy Gateway

**K3d / Minikube (lokalny klaster, bez Gateway API CRD-ów)** — instalacja domyślna z CRD-ami z chart:
```bash
helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.3.2 \
  -n envoy-gateway-system --create-namespace

kubectl wait --timeout=5m -n envoy-gateway-system \
  deployment/envoy-gateway --for=condition=Available
```

**kind (data-plane pinowany na control-plane)** — to samo co K3d/Minikube, **plus** wskazanie gdzie ma wylądować data-plane Envoya. `day1/03_k8s/kind.yaml` mapuje porty 80/443 **tylko na control-plane** (nadaje mu też label `ingress-ready=true`), który ma domyślny taint `node-role.kubernetes.io/control-plane:NoSchedule`. Bez explicit `tolerations` + `nodeSelector` data-plane pod (`envoy-eg-...`, który kontroler tworzy po zaaplikowaniu pierwszego `Gateway`) ląduje na workerze, a ten nie ma 80/443 na host — `curl http://localhost/` nie trafia w Envoya. K3d/Minikube tego nie wymagają (server jest bez tainta, LB mapuje porty niezależnie od node).

```bash
# 1) Standardowa instalacja (jak wyżej)
helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.3.2 \
  -n envoy-gateway-system --create-namespace

kubectl wait --timeout=5m -n envoy-gateway-system \
  deployment/envoy-gateway --for=condition=Available

# 2) EnvoyProxy CR — nodeSelector ingress-ready=true + toleration na control-plane taint
kubectl apply -f envoyproxy-kind.yaml

# 3) Podepnij CR pod GatewayClass "eg" przez parametersRef
kubectl patch gatewayclass eg --type=merge -p '{
  "spec": {
    "parametersRef": {
      "group": "gateway.envoyproxy.io",
      "kind":  "EnvoyProxy",
      "name":  "kind-control-plane",
      "namespace": "envoy-gateway-system"
    }
  }
}'

# Weryfikacja po utworzeniu pierwszego Gateway — data-plane na control-plane
kubectl get pods -n envoy-gateway-system -o wide | grep envoy-eg
# NODE → workshop-control-plane (nie worker).
```

**Managed K8s (DOKS / EKS / GKE / Cilium CNI — Gateway API CRD-y już są)** — dorzuć `--skip-crds`:
```bash
helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.3.2 \
  --skip-crds \
  -n envoy-gateway-system --create-namespace
```

Chart rozprowadzany jako **OCI artifact** z Docker Hub (nie klasyczne repo HTTP — stąd `oci://` zamiast `helm repo add`). Instalacja tworzy `GatewayClass eg` automatycznie.

**Dlaczego `v1.3.2`, a nie `v0.0.0-latest`:** tag latest-dev wymaga CRD-ów w channel `experimental` (m.in. `TLSRoute` w `v1`). Managed K8s (DOKS/Cilium) instaluje Gateway API w channel `standard` — bez `TLSRoute` → Envoy Gateway pada z `no matches for kind "TLSRoute"`. Stabilne release'y (`v1.3.x`) pasują do channel standard. Na produkcji pinuj się na konkretny tag, nie `latest`.

**Dlaczego `--skip-crds` na managed K8s:** DO/EKS/GKE (albo lokalny Cilium) zarządzają CRD-ami Gateway API swoim field managerem. Helm chart Envoy chce zaaplikować te same CRD-y swoim managerem → Server-Side Apply conflict:
```
conflict occurred while applying object /gatewayclasses.gateway.networking.k8s.io:
Apply failed with 4 conflicts: conflicts with "c3"
```
`--skip-crds` każe Helm pominąć `crds/` z chartu i użyć tych, które już są w klastrze.

### cert-manager

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm upgrade --install cert-manager jetstack/cert-manager \
  -n cert-manager --create-namespace \
  --set crds.enabled=true \
  --set config.apiVersion=controller.config.cert-manager.io/v1alpha1 \
  --set config.kind=ControllerConfiguration \
  --set config.enableGatewayAPI=true

kubectl wait --timeout=5m -n cert-manager \
  deployment/cert-manager --for=condition=Available
```

**Dlaczego `crds.enabled=true`:** cert-manager CRD (`Certificate`, `ClusterIssuer`, `Issuer`, `CertificateRequest`, `Challenge`, `Order`) nie instalują się osobnym manifestem. Bez tego flagi `kubectl apply -f certificate.yaml` padnie z `no matches for kind "Certificate"`.

**Dlaczego `config.enableGatewayAPI=true`:** cert-manager domyślnie **nie umie** współpracować z Gateway API — `gateway-shim` kontroler (odpowiada za tworzenie HTTPRoute solverów dla HTTP-01) jest wyłączony. Bez tego Challenge wisi w stanie `pending` z błędem:

```
couldn't Present challenge default/app-tls-...: gateway api is not enabled
```

> **Uwaga — w cert-manager v1.20 to nie jest feature gate.** Wcześniejsze dokumentacje polecają `--set featureGates=ExperimentalGatewayAPISupport=true`. W v1.20 ten flag jest domyślnie `true`, ale **samo to nie włącza Gateway API** — musi być `config.enableGatewayAPI=true` w `ControllerConfiguration` (stąd trzy `--set config.*` powyżej). Weryfikacja w logach:
> ```
> "enabling the sig-network Gateway API certificate-shim and HTTP-01 solver"
> enabled controllers: [... gateway-shim ...]
> ```

> **setup-cluster.sh (K3d) tego nie ma** — bo lokalny K3d nie dociera publicznym IP do Let's Encrypt i Przykład 5 na K3d i tak nie zadziała end-to-end. Dla managed K8s (DOKS/EKS/GKE) te flagi są **wymagane**.

**Rate limit Let's Encrypt:** `letsencrypt-prod` ma limit **50 cert/tydzień/domena** i **5 duplicate cert/tydzień** — podczas iteracji używaj `letsencrypt-staging` (fake CA „Pretend Pear X1", bez limitu, ale cert jest niezaufany i wymaga `-k` w curl). `cluster-issuer-letsencrypt.yaml` w repo definiuje oba — wybierz w `Certificate.spec.issuerRef.name`.

## Sprawdź instalację

```bash
kubectl get pods -n envoy-gateway-system
kubectl get gatewayclass    # powinien być "eg" (envoy gateway)
```

---

## Przykład 1 — Routing po URI (path)

Jeden Gateway, jeden hostname, **routing po prefixie ścieżki**:
- `demo.127-0-0-1.nip.io/` → demo nginx (`app.yaml`)
- `demo.127-0-0-1.nip.io/api` → Python z D1/10 (`python-service:80`)

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

## Przykład 3 — URLRewrite (migracja legacy ścieżki)

Klasyczny produkcyjny case: stare klienty wołają `/old-api/v1/info`, backend przyjmuje tylko `/api/v1/info`. Zamiast zmieniać kod Pythona, dorzucamy **HTTPRoute filter `URLRewrite`** — Envoy przepisuje prefix **zanim** trafi w backend.

```bash
# Upewnij się, że demo-uri z Przykładu 1 jest zaaplikowany (żeby / i /api działały)
kubectl apply -f httproute-uri.yaml

# Dodaj HTTPRoute z URLRewrite: /old-api/* → /api/*
kubectl apply -f httproute-rewrite.yaml
```

Test:
```bash
curl http://demo.127-0-0-1.nip.io/old-api/v1/info   # → ta sama odpowiedź co /api/v1/info
curl http://demo.127-0-0-1.nip.io/api/v1/info       # stary endpoint też działa
```

> **Co się dzieje:** Envoy dopasowuje prefix `/old-api`, filter `URLRewrite.path.ReplacePrefixMatch` podmienia go na `/api`, i dopiero taki request leci do `python-service`. Backend widzi `GET /api/v1/info` — nie musi wiedzieć o legacy ścieżce. Dwa HTTPRoute koegzystują na tym samym hoście: Envoy wybiera **bardziej specyficzny match** (`/old-api` > `/`).

> **Alternatywy filtrów:** `RequestHeaderModifier` (dodaj/usuń header), `RequestRedirect` (301/302 — np. HTTP→HTTPS w Bonus z task.md), `RequestMirror` (shadow traffic do dev), `ResponseHeaderModifier`. Wszystkie deklaratywne, bez annotation hell.

---

## Przykład 4 — TLS self-signed (openssl + `kubernetes.io/tls` Secret)

Zanim wciągniemy cert-manager, warto zobaczyć **czysty Kubernetes TLS**: Gateway API referuje `kubernetes.io/tls` Secret przez `certificateRefs`, a cert generujemy lokalnie openssl-em. Działa offline, bez publicznego IP, bez cert-managera — idealne do lokalnego dev i do zrozumienia, co cert-manager potem automatyzuje.

```bash
# 1) Wygeneruj self-signed cert z SAN-ami dla naszych nip.io domen
openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
  -keyout /tmp/tls.key -out /tmp/tls.crt \
  -subj "/CN=python.127-0-0-1.nip.io" \
  -addext "subjectAltName=DNS:python.127-0-0-1.nip.io,DNS:demo.127-0-0-1.nip.io,DNS:nginx.127-0-0-1.nip.io"

# 2) Wrzuć do klastra jako Secret typu kubernetes.io/tls
kubectl create secret tls app-tls \
  --cert=/tmp/tls.crt --key=/tmp/tls.key \
  --dry-run=client -o yaml | kubectl apply -f -

# 3) Gateway (gateway.yaml) ma już listener HTTPS:443 z certificateRef → Secret "app-tls"
kubectl apply -f gateway.yaml
kubectl apply -f httproute-domain.yaml   # albo httproute-uri.yaml
```

Test:
```bash
# -k bo cert jest self-signed (CA = my sami)
curl -kv https://python.127-0-0-1.nip.io/api/v1/info 2>&1 | grep -E "subject|issuer|HTTP/"
# Spodziewane:
#  * Server certificate: subject: CN=python.127-0-0-1.nip.io
#  * Server certificate: issuer: CN=python.127-0-0-1.nip.io   (self-signed = subject == issuer)
#  < HTTP/2 200
```

> **Co tu robi Gateway API:** listener HTTPS `tls.mode: Terminate` + `certificateRefs: [{kind: Secret, name: app-tls}]`. Envoy Gateway automatycznie ładuje Secret, terminuje TLS w Envoy (aplikacja dostaje plaintext HTTP), i kieruje dalej wg HTTPRoute. Rotacja: podmieniasz Secret → Envoy sam przeładuje cert.

> **Dlaczego to pokazujemy przed cert-managerem:** żeby zobaczyć, że Gateway API **nie wymaga** cert-managera — wymaga tylko Secret typu `kubernetes.io/tls`. cert-manager automatyzuje **produkcję tego Secretu** (wystawianie, renewal, DNS/HTTP challenge). Przykład 5 pokaże to samo, tylko z cert-managerem jako źródłem certa.

---

## Przykład 5 — TLS przez cert-manager (Let's Encrypt staging)

Dorzucamy listener HTTPS:443 do Gateway, certyfikat zarządzany przez cert-manager.

```bash
# cert-manager już z setup-cluster.sh (komenda Helm: patrz sekcja „Instalacja Envoy Gateway + cert-manager (Helm)" wyżej)
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
