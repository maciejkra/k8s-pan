# Zadanie

1. Stwórz dwa Deploymenty:
   - `python-api` (v1) w namespace `prod`
   - `nginx` (v2) w namespace `canary`
2. Stwórz `HTTPRoute` (Gateway API — Envoy Gateway z `D2/07`) z **weighted routing** 70/30: `backendRefs` z polem `weight` po stronie obu Service-ów (70 → `python-api`, 30 → `nginx`).
3. Wykonaj 100 requestów w pętli i policz, ile trafiło na każdą wersję - powinno być ~70/30.
4. Stopniowo zwiększaj udział nowej wersji (50/50 -> 80/20 -> 100% nginx). Po każdym kroku sprawdź ruch.
5. Przeczytaj `strategies.md` w katalogu - wymień różnice między Canary, Blue/Green i A/B testing.

## Bonus

Zainstaluj **Argo Rollouts** i odtwórz to samo z deklaratywnym `Rollout` definiującym `steps` (`setWeight`, `pause`).
