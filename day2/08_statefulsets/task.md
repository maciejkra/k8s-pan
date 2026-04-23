# Zadanie

**Wymień Redis Deployment** (z `D1/10` Python+Redis) **na Redis StatefulSet** z dedykowanym storage przez `volumeClaimTemplates` (mount `/data`, AOF persistence).

> **Uwaga o D1/10:** poprzednia wersja D1/10 miała literówkę `redis-servcie` w nazwie Service. Obecna wersja jest już poprawiona na `redis-service`. Jeśli pracujesz z freshly-cloned repo — wszystko działa. Jeśli masz stare manifesty w klastrze — patrz krok 1 (cleanup).

## Kroki

1. **Cleanup starego Redis z D1/10:**
   ```bash
   kubectl delete deployment redis
   kubectl delete service redis-service redis-servcie 2>/dev/null || true
   ```
   (Usuwamy zarówno nową nazwę jak i starą — na wypadek pozostałości z poprzedniej edycji.)

2. Wdroż `redis.statefulset.yaml` — sprawdź, że Pod nazywa się `redis-0` (nie losowy hash):
   ```bash
   kubectl apply -f redis.statefulset.yaml
   kubectl get pod -l app=redis
   # Spodziewane: redis-0    1/1   Running
   ```

3. Zweryfikuj, że Python (z D1/10) nadal się łączy:
   ```bash
   kubectl logs deploy/python --tail=20
   # Spodziewane: brak errorów connection refused
   ```

4. Wykonaj kilka `POST` na `/api/v1/info` (zwiększ licznik), potem `kubectl delete pod redis-0`. Po odtworzeniu Pod-a — czy licznik przetrwał? Dlaczego?

5. Skala-up StatefulSet do 3 replik:
   ```bash
   kubectl scale sts/redis --replicas=3
   kubectl get pods -l app=redis -w
   ```
   Obserwuj kolejność powstawania Pod-ów — co zauważasz?

6. Wypisz PVC w klastrze — ile ich jest po skalowaniu? Co się stanie z nimi przy `kubectl scale --replicas=1`?

**Pytania:**
- Dlaczego Service `redis-headless` ma `clusterIP: None`? Co to daje StatefulSetowi?
- Czym różni się **stable network identity** (`redis-0.redis-headless.default.svc...`) od zwykłego Service ClusterIP?
- Kiedy Redis powinien być StatefulSetem, a kiedy Deploymentem? (Hint: cache-only vs source of truth)
- Dlaczego PVC nie są usuwane automatycznie przy scale-down? (Kiedy to się zmieniło i jak skonfigurować auto-delete?)

## Bazowe demo (jeśli to twój pierwszy StatefulSet)

Plik `nginx.statefulset.yaml` to prostszy przykład — 5 replik nginx z dedykowanym storage per Pod. Spójrz na różnicę vs Deployment:

- Pody startują **sekwencyjnie** (`nginx-stsf-0` → Ready → `nginx-stsf-1` → Ready → ...)
- Pod ma **stałe imię** (po `delete pod` wraca z tym samym numerem)
- Z innego Pod-a możesz wywołać `curl nginx-stsf-1.stsf-service` — DNS per Pod
- `kubectl scale --replicas=2` usuwa Pod **z najwyższym ordinal** (nie losowy)
