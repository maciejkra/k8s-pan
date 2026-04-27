# Zadanie

Wystaw **aplikację Python** (z `D1/10` Python+Redis) na świat przez **Gateway API** (Envoy Gateway).

## Część 1 — routing po URI

1. Zweryfikuj, że Envoy Gateway działa (`kubectl get pods -n envoy-gateway-system`). Jeśli instalujesz ręcznie (bez `setup-cluster.sh`), najpierw wykonaj komendy Helm z sekcji „Instalacja Envoy Gateway + cert-manager (Helm)" w `README.md`. **Na Kind dodatkowo:** `kubectl apply -f envoyproxy-kind.yaml` (NodePort + nodeSelector — bez tego LoadBalancer Service zostaje pending).
2. Wdroż drugi backend `app.yaml` (demo nginx) — będzie służył jako "drugi serwis" obok Pythona.
3. Stwórz `Gateway` z listenerem HTTP:80 (zobacz `gateway-http.yaml`). Na Kind po pierwszym apply gateway-http.yaml wykonaj `kubectl patch gatewayclass eg --type=merge -p '{"spec":{"parametersRef":{"group":"gateway.envoyproxy.io","kind":"EnvoyProxy","name":"kind-control-plane","namespace":"envoy-gateway-system"}}}'` żeby podpiąć EnvoyProxy CR. Poczekaj, aż status będzie `Programmed=True`.
4. Stwórz `HTTPRoute`, który:
   - kieruje `demo.127-0-0-1.nip.io/api/...` → **Python z D1/10** (`python-service:80` — Service port, nie containerPort 5002!)
   - kieruje `demo.127-0-0-1.nip.io/` → demo nginx (`demo-app:80`)
5. Wykonaj `curl http://demo.127-0-0-1.nip.io/api/v1/info` — czy widzisz odpowiedź Pythona z licznikiem z Redis?

## Część 2 — routing po nazwie domeny (nip.io)

1. Zamień routing po path na **routing po hostname** — dwa osobne `HTTPRoute`:
   - `python.127-0-0-1.nip.io` → Python z D1/10
   - `nginx.127-0-0-1.nip.io` → demo nginx
2. Sprawdź `curl`-em obie domeny. Co Envoy używa do dopasowania reguły? (`Host` header)

## Część 3 — URLRewrite (migracja legacy ścieżki)

1. Dorzuć drugi `HTTPRoute` (`httproute-rewrite.yaml`) z filterem `URLRewrite` typu `ReplacePrefixMatch`, który kieruje `demo.127-0-0-1.nip.io/old-api/*` do `python-service:80` i **przepisuje prefix** `/old-api` → `/api` zanim request trafi w backend.
2. Wykonaj `curl http://demo.127-0-0-1.nip.io/old-api/v1/info` i `curl http://demo.127-0-0-1.nip.io/api/v1/info` — obie ścieżki mają zwrócić tę samą odpowiedź z Pythona.
3. Sprawdź w `kubectl describe httproute demo-rewrite`, że `ResolvedRefs=True`. Dlaczego `demo-rewrite` nie koliduje z istniejącym `demo-uri` (ten sam hostname, inny prefix)?

## Część 4 — TLS self-signed (openssl + `kubernetes.io/tls` Secret)

1. Wygeneruj self-signed cert `openssl`-em (z SAN-ami dla trzech domen nip.io: `demo.`, `python.`, `nginx.`).
2. Zaaplikuj Secret typu `kubernetes.io/tls` o nazwie `app-tls` (tej oczekuje Gateway w `gateway-https.yaml`).
3. `kubectl apply -f gateway-https.yaml` — dorzuca listener `https` z `certificateRefs: [{Secret: app-tls}]` do istniejącego Gateway `training-gateway`. Po apply oba listenery (HTTP:80 + HTTPS:443) powinny być `Programmed=True`.
4. `curl -kv https://python.127-0-0-1.nip.io/api/v1/info` — w logach `curl -v` znajdź linie `subject:` i `issuer:`. Co potwierdza, że to self-signed?
5. **Pytanie:** co się stanie, jeśli podmienisz Secret `app-tls` na nowy (inny klucz/cert) bez restartu Envoy? Dlaczego?

## Część 5 — TLS przez cert-manager

1. Zaaplikuj `cluster-issuer-letsencrypt.yaml` (Let's Encrypt **staging**). Jeśli `kubectl` zwraca `no matches for kind "ClusterIssuer"`, cert-manager nie jest zainstalowany — patrz sekcja „Instalacja Envoy Gateway + cert-manager (Helm)" w `README.md`. Jeśli `Challenge` wisi z `gateway api is not enabled`, cert-manager nie ma włączonego `config.enableGatewayAPI=true` — tamże.
2. Zaaplikuj `certificate.yaml` po podmianie domeny na własną nip.io z **publicznym IP** (HTTP-01 wymaga, by LE mógł dotrzeć do Twojego IP od strony internetu).
3. Sprawdź `kubectl describe certificate app-tls` — jakie eventy?
4. Sprawdź, że `Secret` `app-tls` powstał i jest referencowany przez Gateway listener HTTPS.
5. `curl -k https://python.<TWOJ-IP>.nip.io/api/v1/info` — flaga `-k` bo staging używa fake-CA.

**Pytania:**
- Czym `HTTPRoute` różni się od legacy `Ingress`? Wymień **3** różnice.
- Dlaczego nie da się wystawić cert przez **HTTP-01** dla `127-0-0-1.nip.io` z lokalnego klastra? Co zrobić alternatywnie?
- Jaką rolę pełni `GatewayClass` w role-oriented modelu Gateway API?

## Bonus

Skonfiguruj Gateway tak, żeby **przekierowywał HTTP → HTTPS** (cały ruch z `:80` lecący na `:443`) — w spec listenerów Envoy Gateway lub jako dodatkowy `HTTPRoute` z `requestRedirect` filterem.
