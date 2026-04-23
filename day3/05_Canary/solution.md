# Solution — 05_Canary (odpowiedzi + walidacja)

> Szczegóły architektury i pełen walkthrough → [`solution/README.md`](./solution/README.md).

## Odpowiedzi

### Weighted HTTPRoute vs replica-ratio (3 różnice)

1. **Granularność**: replica-ratio zmienia się dyskretnie (7:3 = 70%, 3:7 = 30%, ale `1%` wymaga 99:1 = 100 replik). HTTPRoute weight to int 0-10000 (dowolna precyzja).
2. **Koszt zmiany**: replica-ratio wymaga skalowania (nowe Pody wstają, zajmują miejsce). HTTPRoute weight = update manifestu, Envoy re-programuje config w ~1s bez restartu Pod-a.
3. **Orthogonalność**: z HTTPRoute możesz **równocześnie** mieć canary (weight) i scale replicas niezależnie (HPA). Replica-ratio nie — HPA zaburza ratio.

### weight: 0 dla v1

Ruch idzie 100% na v2. Pody v1 wciąż żyją i konsumują CPU/memory. To jest **celowe** w canary workflow:
- Stabilizacja 24-48h na weight=0 przed usunięciem v1 (gdybyśmy wracali wstecz).
- `kubectl patch` weight=0 to szybki "kill switch" dla buggy v1 bez scaling-to-zero (który może generować event storm w HPA/scheduler).

### Canary vs Blue/Green

**Canary** — scenariusze:
- Feature flag rollout (10% userów widzi nowy UI, jeśli engagement OK → 100%)
- Database migration z nową wersją app (nowa wersja czyta nowy schema; v1 czyta stary; stopniowy cutover przy trwającym ruchu)

**Blue/Green** — scenariusze:
- Legacy monolith bez stateless guarantee (trudno równolegle prowadzić 2 wersje)
- Compliance: audit wymaga "konkretny moment T w którym przełączyliśmy" (canary nie daje jednej chwili, tylko stopniowe)

Praktyczna zasada: canary dla cloud-native stateless microservices, Blue/Green dla monolitów i DB migrations.

### Co dodają Argo Rollouts / Flagger

1. **Automated metric analysis** — po każdym `setWeight` czeka X minut, pyta Prometheus: czy error rate < 1%? Jeśli nie → auto-rollback.
2. **Pre-promotion hooks / analysis templates** — integration z Datadog, New Relic, custom scripts. Pauza dopóki SLO nie OK.
3. **Deklaratywny `Rollout` CRD** — zastępuje `Deployment`, ma `spec.strategy.canary.steps` (YAML = workflow, łatwiejsze niż manualny `kubectl patch` loop).

Dodatkowo: Argo Rollouts integruje się z Argo CD (GitOps) — commit w Git = nowy canary step.

### Shadow traffic z `RequestMirror`

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
spec:
  rules:
    - filters:
        - type: RequestMirror
          requestMirror:
            backendRef:
              name: canary-app-v2    # shadow target
              port: 80
      backendRefs:
        - name: canary-app-v1
          port: 80                   # primary (user dostaje tę response)
```

Ruch kopiowany do v2, ale response z v1 wraca do usera. Shadow idealny dla:
- **Perf testing** — czy v2 wytrzyma 100% produkcji RPS?
- **Compatibility check** — czy v2 zwraca te same dane? (porównanie offline)

Limitacje: v2 ma side-effects (write do DB)? Shadow zrobi duplikat insertów. Potrzebne separate staging DB albo read-only tryb v2.

## Walidacja end-to-end

```bash
# 1. Deploy
kubectl apply -f solution/
kubectl wait --for=condition=ready pod -l app=canary-app --timeout=60s

# 2. Gateway/HTTPRoute status
kubectl get httproute canary-demo -o jsonpath='{.status.parents[0].conditions}' | jq
# conditions: [ {type: Accepted, status: True}, {type: ResolvedRefs, status: True} ]

# 3. Rozkład ruchu
for i in $(seq 1 100); do
  curl -s canary.127-0-0-1.nip.io | grep -oE 'blue|green'
done | sort | uniq -c
# 70 blue, 30 green (±5)

# 4. Progressive rollout
kubectl patch httproute canary-demo --type=json -p='[
  {"op":"replace","path":"/spec/rules/0/backendRefs/0/weight","value":50},
  {"op":"replace","path":"/spec/rules/0/backendRefs/1/weight","value":50}
]'
sleep 5
for i in $(seq 1 100); do curl -s canary.127-0-0-1.nip.io | grep -oE 'blue|green'; done | sort | uniq -c
# 50 blue, 50 green
```

## Troubleshooting

### HTTPRoute `Accepted=False`

```bash
kubectl describe httproute canary-demo
# Events albo Reason w conditions — np. "NoMatchingParent"
```
Typowe:
- Gateway `training-gateway` nie istnieje w namespace (D2/07 nie wdrożone). Fix: `kubectl apply -f day2/07_gateway_api/gateway-http.yaml`.
- Hostname `canary.127-0-0-1.nip.io` konflikuje z innym HTTPRoute na tym Gateway. Sprawdź `kubectl get httproute -A`.

### Ratio 100/0 zamiast 70/30

- Envoy cache'uje DNS ~30s — świeżo utworzony Service może nie być widoczny natychmiast. Poczekaj.
- Weight interpretacja w Envoy: jeśli jeden backend NotReady (`ResolvedRefs=False`), Envoy kieruje 100% na drugi. Sprawdź że oba Service mają endpoints.

### Canary-demo Argo Rollouts nie startuje

`canary-demo/` używa legacy tooling (`glide` instead of `go mod`, old NGINX Ingress annotations). Katalog pozostaje jako **historyczny reference**, nie działa out-of-the-box w 2026. Pełny działający setup: użyj Argo Rollouts Quick Start (https://argoproj.github.io/argo-rollouts/getting-started/).

## Cross-link

- D2/07 (Gateway API) — używamy `training-gateway` i `weightedBackendRefs`
- D3/04 (HPA) — HPA niezależne od weight; każda wersja skala się osobno
- D3/08 (NetworkPolicy) — możesz ograniczyć który NS dostaje canary ruch (np. tylko `staging-ns` klientom)
- D4/03 (ValidatingAdmissionPolicy) — egzekwowanie "Rollout musi mieć minimum 3 steps" policy
