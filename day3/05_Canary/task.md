# Zadanie

## Część 1 — Deploy dwie wersje

```bash
kubectl apply -f solution/deployment-v1.yaml
kubectl apply -f solution/deployment-v2.yaml
kubectl wait --for=condition=ready pod -l app=canary-app --timeout=60s
```

Sprawdź:
```bash
kubectl get pods -l app=canary-app --show-labels
# 2 Pody version=v1 (pkad:blue)
# 1 Pod version=v2 (pkad:green)
```

## Część 2 — HTTPRoute z weight 70/30

```bash
kubectl apply -f solution/httproute-canary.yaml
sleep 5
kubectl describe httproute canary-demo
# Status.Parents[0].conditions: Accepted=True, ResolvedRefs=True
```

## Część 3 — Test rozkładu

```bash
for i in $(seq 1 100); do
  curl -s canary.127-0-0-1.nip.io | grep -oE 'blue|green'
done | sort | uniq -c
# Spodziewane: ~70 blue, ~30 green (±5% statystyczna zmienność)
```

## Część 4 — Progresywnie zwiększaj v2

```bash
# 50/50
kubectl patch httproute canary-demo --type=json -p='[
  {"op":"replace","path":"/spec/rules/0/backendRefs/0/weight","value":50},
  {"op":"replace","path":"/spec/rules/0/backendRefs/1/weight","value":50}
]'

# Powtórz pomiar — powinno być ~50/50

# Potem 20/80, potem 0/100
```

Po każdym kroku w produkcji: pauza na monitoring (Prometheus error rate, latency p99, business metrics). Jeśli SLO spada → rollback (przywróć weight).

## Część 5 — Header-based routing (bonus)

Zmień HTTPRoute na dwa rule: jeden z header match `x-canary-tester: true` → 100% v2, drugi catch-all → 100% v1. Patrz `solution/README.md` "Header-based canary" section.

## Pytania

1. Weighted HTTPRoute vs replica-ratio canary (stary wzorzec bez Gateway API) — wymień 3 różnice.
2. Co się stanie jeśli ustawisz `weight: 0` dla v1 ale v1 Service istnieje i ma Pody? (Hint: traffic idzie 100% na v2, ale Pody v1 nadal liczą koszty.)
3. Canary vs Blue/Green — kiedy które wybierzesz? (2 konkretne scenariusze każde.)
4. Co Argo Rollouts / Flagger dodają ponad to co pokazaliśmy ręcznie? (3 rzeczy.)
5. **Bonus**: jak zaimplementować **shadow traffic** (duplikacja requestów do v2 bez zwracania response) w HTTPRoute? (Hint: filter type `RequestMirror`.)

## Bonus — Argo Rollouts

Zainstaluj Argo Rollouts i odtwórz powyższe deklaratywnie:

```bash
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
```

Dla pełnego przykładu własnej aplikacji w Go z Argo Rollouts — patrz `canary-demo/` (advanced track).
