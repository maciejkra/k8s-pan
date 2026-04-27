# Solution — 07_gateway_api

## Gdzie wziąć Envoy Gateway / cert-manager

Oba instaluje `setup-cluster.sh`; komendy Helm 1:1 są w `README.md` → sekcja „Instalacja Envoy Gateway + cert-manager (Helm)". Domyślne wartości użyte w kursie:

- **Envoy Gateway**: chart `oci://docker.io/envoyproxy/gateway-helm`. Lokalny K3d — wersja `v0.0.0-latest`, domyślnie z CRD-ami. Managed K8s (DOKS/EKS/GKE z Cilium) — wersja **stabilna** (`v1.3.2`) + `--skip-crds` (bo CNI już ma Gateway API CRD — `v0.0.0-latest` wymaga channel `experimental`, którego managed klastry nie mają).
- **cert-manager**: chart `jetstack/cert-manager`, namespace `cert-manager`, `--set crds.enabled=true` + **dla Gateway API**: `--set config.apiVersion=controller.config.cert-manager.io/v1alpha1 --set config.kind=ControllerConfiguration --set config.enableGatewayAPI=true`. Bez tego ostatniego Challenge zawisa z `gateway api is not enabled`.

Weryfikacja: `kubectl get gatewayclass eg` → `Accepted=True`; `kubectl logs -n cert-manager deployment/cert-manager | grep gateway-shim` → kontroler `gateway-shim` w liście enabled controllers.

## Zweryfikowane na klastrze produkcyjnym

End-to-end setup sprawdzony na **Digital Ocean DOKS k8s 1.35 (Cilium CNI)**:
- DO LoadBalancer zapewnia publiczne IP dla Service `envoy-default-training-gateway-*`.
- cert-manager wystawił prawdziwy cert Let's Encrypt (`issuer: CN=R12, O=Let's Encrypt`) dla domeny `python.<DO-LB-IP>.nip.io` przez HTTP-01 challenge z `gatewayHTTPRoute` solverem.
- Czas od `kubectl apply -f certificate.yaml` do `Ready=True`: ~90 s (2 solver HTTPRoute utworzone przez cert-manager, zwalidowane przez 6 regionalnych nodów Let's Encrypt).

## Odpowiedzi

### GatewayClass vs Gateway
- **GatewayClass** = template / kontroler. Mówi "zaprogramuję to przez Envoy" lub "przez NGINX".
- **Gateway** = instancja. "Chcę LB słuchający na portach 80/443 z tymi listenerami".

Rozdzielenie pozwala jednemu klasterowi mieć kilka Gateway różnych implementacji (np. Envoy dla north-south, Cilium dla east-west).

### HTTP-01 bez publicznego IP
HTTP-01 challenge wymaga, żeby Let's Encrypt dotarł do `http://<dnsName>/.well-known/acme-challenge/<token>`. Bez publicznego IP/DNS to nie zadziała.

Obejścia w devie:
1. **DNS-01 challenge** — używa rekordu TXT zamiast HTTP. Działa bez publicznego IP, ale wymaga API klucza do providera DNS (Cloudflare, Route53).
2. **`cloudflared tunnel`** lub **ngrok** — tymczasowy publiczny URL.
3. **Self-signed ClusterIssuer** — bez Let's Encrypt, dla testów wewnętrznych:
   ```yaml
   apiVersion: cert-manager.io/v1
   kind: ClusterIssuer
   metadata: { name: selfsigned }
   spec: { selfSigned: {} }
   ```
4. **Staging Let's Encrypt** — wystawia cert ale z fake CA, akceptuje proste HTTP-01 (czasem działa z `127.0.0.1` jeśli `/etc/hosts` skonfigurowany).

### Renewal
cert-manager kontroler ma reconciliation loop. Gdy `now + renewBefore >= notAfter`, tworzy nowy CertificateRequest, dostaje cert, podmienia Secret. Aplikacja musi wykryć zmianę Secretu — Envoy/NGINX automatycznie reload, custom apps mogą potrzebować watch+SIGHUP.

### ingress2gateway
```bash
brew install ingress2gateway
ingress2gateway print --providers ingress-nginx --input-file legacy-ingress.yaml > gateway-api.yaml
```
Generuje GatewayClass + Gateway + HTTPRoute z Ingress. Adnotacje specyficzne dla NGINX (np. `nginx.ingress.kubernetes.io/rewrite-target`) wymagają ręcznego mapowania na `URLRewrite` filter.

### "Annotation hell"
W Ingress: routing po hostname, ale wszystko inne (rewrite, auth, rate-limit, CORS, headers) przez **annotations** specyficzne per controller. Manifest "działa na NGINX" niekoniecznie działa na Traefik.

W Gateway API: routing **i** filters są w spec. Standardowe: `RequestHeaderModifier`, `URLRewrite`, `RequestRedirect`, `RequestMirror`. Custom filters przez `ExtensionRef` — ale i tak typowane CRD, nie stringi.

## Walidacja end-to-end (lokalnie z /etc/hosts)

```bash
# 1. Zdobądź IP K3d LB (zazwyczaj 127.0.0.1 jeśli porty zmapowane)
echo "127.0.0.1 app.example.com" | sudo tee -a /etc/hosts

# 2. Zaaplikuj wszystko (gateway-https zawiera HTTPS listener wymagający Secret app-tls)
kubectl apply -f app.yaml -f gateway-http.yaml -f cluster-issuer-letsencrypt.yaml \
              -f certificate.yaml -f httproute.yaml
# Dopiero po Ready certificate:
# kubectl apply -f gateway-https.yaml

# 3. Czekaj na cert (może zająć 1-3 min)
kubectl wait --for=condition=Ready certificate/app-tls --timeout=5m

# 4. Test
curl -kv https://app.example.com/
# Spodziewane: HTTP 200, cert wystawiony przez "(STAGING) Let's Encrypt"
```

## Troubleshooting

- `Gateway` Programmed=False → sprawdź `kubectl describe gateway training-gateway` i logi Envoy: `kubectl logs -n envoy-gateway-system deploy/envoy-gateway`
- `Certificate` Ready=False → `kubectl describe certificate app-tls` + `kubectl describe challenge` — najczęściej DNS nie wskazuje na klaster lub HTTP-01 path nie odpowiada
- Rate limit Let's Encrypt → tylko **staging** używać podczas iteracji; prod max 50 cert/tydzień per domena
