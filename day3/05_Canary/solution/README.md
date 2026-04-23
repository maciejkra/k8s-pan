# Solution — 05_Canary

## Architektura

```
       Client
         │  curl canary.127-0-0-1.nip.io
         ▼
   [Envoy Gateway]  (D2/07 training-gateway)
         │
         ▼
   [HTTPRoute canary-demo]  ← weighted routing 70/30
         ├──70%──→ Service canary-app-v1 ──→ 2× Pod pkad:blue
         └──30%──→ Service canary-app-v2 ──→ 1× Pod pkad:green
```

## Pliki

- `deployment-v1.yaml` — v1 Deployment + Service (2 repliki, pkad:blue)
- `deployment-v2.yaml` — v2 Deployment + Service (1 replika, pkad:green)
- `httproute-canary.yaml` — HTTPRoute z `backendRefs[].weight` 70/30

Kluczowe różnice vs poprzednie podejście (PVC + 2 Deployment na wspólnym Service):

| | Stare (service selector) | Nowe (weighted HTTPRoute) |
|---|---|---|
| Sterowanie ratio | `replicas v1=7, v2=3` → ratio pod/pod | `weight: 70/30` w HTTPRoute |
| Granularność | tylko liczba replik całkowita (1% = 1/100 replik = 100 Pod-ów) | dowolna % (HTTPRoute weight to int) |
| Cross-version config | trudny (ten sam Service) | łatwy (osobne Service) |
| Header/cookie routing | niemożliwe | możliwe (dodać `matches.headers` do jednej rule) |
| Gdy `replicas: 0` | 100% ruchu na drugi | ruch nadal idzie — 5xx z upstream → Gateway retry |

## Apply

```bash
# (Gateway training-gateway z D2/07 musi istnieć i być Programmed)
kubectl apply -f deployment-v1.yaml
kubectl apply -f deployment-v2.yaml
kubectl wait --for=condition=ready pod -l app=canary-app --timeout=60s

kubectl apply -f httproute-canary.yaml
sleep 5   # Envoy program config
```

## Walidacja

```bash
# 100 requestów, policzmy rozkład
for i in $(seq 1 100); do
  curl -s canary.127-0-0-1.nip.io | grep -oE 'blue|green'
done | sort | uniq -c
# Spodziewane: ~70 blue, ~30 green (±5% statystyczna zmienność)
```

## Rolling the canary forward

Progresywne zwiększanie weight v2:

```bash
# 50/50
kubectl patch httproute canary-demo --type=json -p='[
  {"op":"replace","path":"/spec/rules/0/backendRefs/0/weight","value":50},
  {"op":"replace","path":"/spec/rules/0/backendRefs/1/weight","value":50}
]'

# 20/80 (v2 dominuje)
kubectl patch httproute canary-demo --type=json -p='[
  {"op":"replace","path":"/spec/rules/0/backendRefs/0/weight","value":20},
  {"op":"replace","path":"/spec/rules/0/backendRefs/1/weight","value":80}
]'

# 100% v2 (canary promoted do stable)
kubectl patch httproute canary-demo --type=json -p='[
  {"op":"replace","path":"/spec/rules/0/backendRefs/0/weight","value":0},
  {"op":"replace","path":"/spec/rules/0/backendRefs/1/weight","value":100}
]'

# Po tygodniu stabilności: zmień v2 → v1 (nowy canary mo będzie v3) i usuń stary Deployment
```

W produkcji **Argo Rollouts** albo **Flagger** robi to automatycznie — monitoruje SLO (error rate, latency) między krokami i rolluje wstecz jeśli threshold przekroczony. Bez automatyki: ręczny workflow musi być dokumentowany (runbook per zespół).

## Header-based canary (preview)

Chcesz że tylko **Twój team** dostaje canary? Dodaj header match na wszystkie 100% v2:

```yaml
rules:
  - matches:
      - headers:
          - name: x-canary-tester
            value: "true"
    backendRefs:
      - name: canary-app-v2
        port: 80
  - matches:
      - path: { type: PathPrefix, value: / }
    backendRefs:
      - name: canary-app-v1
        port: 80
```

Test:
```bash
curl -H "x-canary-tester: true" canary.127-0-0-1.nip.io   # zawsze green
curl canary.127-0-0-1.nip.io                              # zawsze blue
```
