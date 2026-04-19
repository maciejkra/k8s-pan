# Strategie wdrożeń aplikacji w K8s

> Markdown uzupełniający `day3/05_Canary` o porównanie wszystkich strategii z agendy.

## 6 strategii

### 1. Recreate
Zatrzymaj wszystkie stare Pody → uruchom nowe. **Downtime gwarantowany**.

```yaml
spec:
  strategy:
    type: Recreate
```

✅ Proste, deterministyczne
✅ Brak konfliktów wersji w runtime (np. schema bazy)
❌ Downtime
❌ Brak rollback w trakcie

**Kiedy**: dev, batch jobs, aplikacje stateful nie obsługujące dwóch wersji równolegle.

---

### 2. Rolling Update (default)
Stopniowo wymieniaj Pody — `maxSurge` extra spaceholder, `maxUnavailable` ile może być down.

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 25%               # +25% extra Pody w trakcie
      maxUnavailable: 0           # zawsze 100% dostępne
```

✅ Bez downtime
✅ Built-in K8s, nic dodatkowego
✅ Auto-rollback na fail readinessProbe
❌ Krótkotrwałe N + 1 wersji w runtime (kompatybilność wsteczna API)
❌ Rollback liniowy (czas = czas rolloutu)

**Kiedy**: 80% przypadków produkcyjnych, gdy aplikacja toleruje równoległe wersje.

---

### 3. Blue / Green
Cała nowa wersja deploy obok starej, switch ruchu **atomowo** (Service selector).

```yaml
# Service selektorem wskazuje "blue" lub "green"
apiVersion: v1
kind: Service
metadata: { name: app }
spec:
  selector:
    app: my-app
    color: blue                   # zmiana na "green" = atomic switch
```

```bash
kubectl set selector svc/app color=green     # instant switch
```

✅ Atomic switch — zero okna mieszanego ruchu
✅ Instant rollback (switch z powrotem)
✅ Pełny smoke test przed switchem
❌ 2× zasoby w trakcie (cała kopia produkcji)
❌ Schema migration trudna (oba env muszą działać z tym samym schemą)

**Kiedy**: krytyczne aplikacje, gdzie nawet 1% mieszanego ruchu jest niedopuszczalny (banking, healthcare).

---

### 4. Canary
Małe % ruchu na nową wersję, monitoruj metryki, stopniowo zwiększaj.

```
v1: 95% ruchu  →  v1: 80% / v2: 20%  →  v1: 50% / v2: 50%  →  v2: 100%
                  ↑ pomiar metryk po każdym kroku
```

Implementacje:
- **Manualnie**: dwa Deploymenty + wagi w Service mesh / Gateway API
- **Argo Rollouts** (rekomendowane) — automated canary z metryk Prometheus
- **Flagger** — analogicznie, integracja z Istio/Linkerd

✅ Najmniejszy blast radius — wadliwa wersja dotyka 1-5% userów
✅ Real-traffic testing
✅ Auto-rollback przy regresji metryki
❌ Wymaga observability (metryki latency, error rate)
❌ Wolniejszy rollout (godziny / dni)

**Kiedy**: produkty z dobrymi metrykami business (conversion, error rate), wystarczy traffic żeby statistically significant.

→ **Patrz katalog `canary-demo/` w tym folderze dla działającego przykładu.**

---

### 5. A/B Testing
Wariant Canary, ale routing **per użytkownik** zamiast per request:
- User w cohort A → zawsze v1
- User w cohort B → zawsze v2

Gateway API HTTPRoute z `headerMatch` (cookie z user_id):
```yaml
matches:
  - headers:
      - { name: cookie, value: "experiment_group=B" }
backendRefs:
  - { name: app-v2, port: 80 }
```

✅ Statystycznie czystsze testy biznesowe (user widzi spójne UX)
✅ Integracja z product analytics (Mixpanel, Amplitude)
❌ Tylko dla user-facing (nie dla backend services bez user context)
❌ Nie służy do "deployment safety" — tylko do testów hipotez biznesowych

**Kiedy**: wybór designu, testowanie nowych feature flag, NIE jako standardowy deploy mechanism.

---

### 6. Shadow / Mirror
Cały ruch trafia do v1 (production), **kopia** wysyłana do v2 (shadow). Odpowiedź v2 ignorowana.

Implementacja: Istio `VirtualService.mirror`, lub Envoy `request_mirror_policies`, Gateway API `RequestMirror` filter.

```yaml
filters:
  - type: RequestMirror
    requestMirror:
      backendRef:
        name: app-v2
        port: 80
```

✅ Real production load na nową wersję bez ryzyka
✅ Wykrycie bugów które tylko production traffic ujawnia (race conditions, edge cases)
❌ 2× compute koszt
❌ Side effects v2 (zapis do bazy, wysyłanie maili) muszą być mockowane
❌ Skomplikowane debugging gdy v2 zachowuje się inaczej

**Kiedy**: krytyczne refactory backendu (np. nowy storage engine), performance regression testing.

---

## Tabela porównawcza

| Strategia | Downtime | Resource | Rollback | Złożoność | Risk |
|---|---|---|---|---|---|
| Recreate | TAK | 1× | trudny | minimalna | duży |
| Rolling | NIE | 1.25× | wolny | niska | mały |
| Blue/Green | NIE | 2× | natychmiastowy | średnia | mały |
| Canary | NIE | 1.x× | natychmiastowy | wysoka | minimalny |
| A/B | NIE | 2× | per cohort | wysoka | biznesowy |
| Shadow | NIE | 2× | n/a (read-only) | bardzo wysoka | minimalny |

## Decyzja "który wybrać?"

```
Czy stateless app + toleruje N+1 wersji? 
  → TAK: Rolling (default K8s)
  → NIE: Recreate (z planowanym downtime)

Czy masz observability + business metrics?
  → TAK: Canary z auto-promote/rollback (Argo Rollouts)
  → NIE: Blue/Green dla atomic switch

Czy testujesz feature business (nie deploy safety)?
  → TAK: A/B testing per user

Czy refactor backendu z możliwymi performance regressions?
  → TAK: Shadow mirror przed prawdziwym deploy
```

## Linki
- [Argo Rollouts](https://argoproj.github.io/argo-rollouts/) — recommended dla Canary/BlueGreen
- [Flagger](https://flagger.app/) — alternatywa, integracja z service mesh
- [Continuous Delivery for K8s (Lukasa)](https://blog.container-solutions.com/kubernetes-deployment-strategies)
