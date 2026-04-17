# 07 — Eksponowanie usług: Gateway API + cert-manager + Let's Encrypt

## Cel
Wystawić aplikację HTTPs przez **Gateway API** (Envoy Gateway) z automatycznym certyfikatem od **Let's Encrypt** generowanym przez **cert-manager**.

## Kontekst
**Gateway API** (GA od K8s 1.29) zastępuje legacy Ingress. Główne różnice:
- **role-oriented model**: trzy CRD-y, trzy role:
  - `GatewayClass` — definiuje implementację (Envoy, NGINX, …) — *infra admin*
  - `Gateway` — instancja LB z portami i listenerami — *cluster operator*
  - `HTTPRoute` (lub `TCPRoute`, `GRPCRoute`) — reguły routing — *app dev*
- **typed routes**: HTTPRoute, TCPRoute, TLSRoute, GRPCRoute — nie tylko HTTP
- **portable**: ten sam manifest działa z Envoy Gateway, NGINX Gateway Fabric, Cilium, Istio, …
- **expressive**: header/method/queryParam matching out-of-the-box, bez annotations hell

**cert-manager** automatyzuje cykl życia certów:
- `ClusterIssuer` — gdzie po cert (Let's Encrypt prod/staging, Vault, self-signed)
- `Certificate` — żądanie cert dla konkretnego DNS, cert-manager dba o wystawienie i odnowienie
- challenges: HTTP-01 (proste, wymaga publicznego IP/DNS) lub DNS-01 (wymaga API providera DNS, działa bez publicznego IP)

W tym ćwiczeniu używamy **Let's Encrypt staging** + HTTP-01.

## Prereqs
- K3d cluster z `setup-cluster.sh` (Envoy Gateway + cert-manager już zainstalowane)
- Aplikacja demo (zbudujemy szybki nginx)
- **Publiczny DNS** wskazujący na klaster — opcje:
  - lokalnie: użyj `staging` issuer (nie wymaga prawdziwej walidacji) + edytuj `/etc/hosts` dla testu
  - prod: `cloudflared tunnel` lub publiczny IP

## Zadanie

1. Sprawdź, że Envoy Gateway i cert-manager działają:
   ```bash
   kubectl get pods -n envoy-gateway-system
   kubectl get pods -n cert-manager
   kubectl get gatewayclass    # powinien być "eg" (envoy gateway)
   ```

2. Wdroż aplikację demo:
   ```bash
   kubectl apply -f app.yaml
   ```

3. Stwórz GatewayClass + Gateway (listenery 80 i 443):
   ```bash
   kubectl apply -f gateway.yaml
   kubectl get gateway -n default -w
   ```
   Czekaj aż status `Programmed=True`.

4. Stwórz ClusterIssuer (Let's Encrypt staging):
   ```bash
   kubectl apply -f cluster-issuer-letsencrypt.yaml
   kubectl get clusterissuer -w
   ```

5. Wystaw Certificate dla domeny:
   ```bash
   # Edytuj certificate.yaml — zmień app.example.com na swoją domenę
   kubectl apply -f certificate.yaml
   kubectl describe certificate app-tls   # śledź "Events"
   ```

6. Stwórz HTTPRoute kierującą ruch do aplikacji:
   ```bash
   kubectl apply -f httproute.yaml
   ```

7. Test:
   ```bash
   # Lokalnie z /etc/hosts wskazującym na 127.0.0.1:
   curl -k https://app.example.com/
   # -k bo Let's Encrypt staging używa fake-CA "Pretend Pear X1"
   ```

## Pytania kontrolne
1. Co dokładnie różni `GatewayClass` od `Gateway`? Po co rozdzielenie?
2. Dlaczego HTTP-01 challenge nie zadziała bez publicznego IP/DNS? Jak to obejść w devie?
3. Co się stanie, gdy `Certificate.spec.duration` przekroczy czas życia? Kto odnawia?
4. Jak migrować istniejący Ingress do Gateway API? (Hint: `ingress2gateway` CLI)
5. W jaki sposób Gateway API rozwiązuje problem "ingress annotation hell"?

## Linki
- [Gateway API spec](https://gateway-api.sigs.k8s.io/)
- [Envoy Gateway](https://gateway.envoyproxy.io/)
- [cert-manager docs](https://cert-manager.io/docs/)
- [ingress2gateway migration tool](https://github.com/kubernetes-sigs/ingress2gateway)
