# Zadanie

Wystaw **aplikację Python** (z `D1/10` Python+Redis) na świat przez **Gateway API** (Envoy Gateway).

## Część 1 — routing po URI

1. Zweryfikuj, że Envoy Gateway działa (`kubectl get pods -n envoy-gateway-system`) i że istnieje GatewayClass `eg`.
2. Wdroż drugi backend `app.yaml` (demo nginx) — będzie służył jako "drugi serwis" obok Pythona.
3. Stwórz `Gateway` z listenerem HTTP:80 (zobacz `gateway.yaml`). Poczekaj, aż status będzie `Programmed=True`.
4. Stwórz `HTTPRoute`, który:
   - kieruje `demo.127-0-0-1.nip.io/api/...` → **Python z D1/10** (`python-service:5002`)
   - kieruje `demo.127-0-0-1.nip.io/` → demo nginx (`demo-app:80`)
5. Wykonaj `curl http://demo.127-0-0-1.nip.io/api/v1/info` — czy widzisz odpowiedź Pythona z licznikiem z Redis?

## Część 2 — routing po nazwie domeny (nip.io)

1. Zamień routing po path na **routing po hostname** — dwa osobne `HTTPRoute`:
   - `python.127-0-0-1.nip.io` → Python z D1/10
   - `nginx.127-0-0-1.nip.io` → demo nginx
2. Sprawdź `curl`-em obie domeny. Co Envoy używa do dopasowania reguły? (`Host` header)

## Część 3 — TLS przez cert-manager

1. Zaaplikuj `cluster-issuer-letsencrypt.yaml` (Let's Encrypt **staging**).
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
