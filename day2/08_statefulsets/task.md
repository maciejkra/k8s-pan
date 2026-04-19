# Zadanie

**Wymień Redis Deployment** (z `D1/10` Python+Redis) **na Redis StatefulSet** z dedykowanym storage przez `volumeClaimTemplates` (mount `/data`, AOF persistence).

1. Usuń poprzedni Redis Deployment z D1/10 (zostaw Python).
2. Wdroż `redis.statefulset.yaml` — sprawdź, że Pod nazywa się `redis-0` (nie losowy hash).
3. Zweryfikuj, że Python (z D1/10) nadal się łączy — `kubectl logs deploy/python` powinno pokazywać udane połączenia z Redis (env `REDIS_HOST=redis-servcie`).
4. Wykonaj kilka POST-ów na `/api/v1/info` (zwiększ licznik), potem `kubectl delete pod redis-0`. Po odtworzeniu Pod-a — czy licznik przetrwał? Dlaczego?
5. Skala-up StatefulSet do 3 replik. Obserwuj kolejność powstawania Pod-ów — co zauważasz?
6. Wypisz PVC w klastrze — ile ich jest po skalowaniu? Co się stanie z nimi przy `scale --replicas=1`?

**Pytania:**
- Dlaczego Service `redis-headless` ma `clusterIP: None`? Co to daje StatefulSetowi?
- Czym różni się **stable network identity** (`redis-0.redis-headless.default.svc...`) od zwykłego Service ClusterIP?
- Kiedy Redis powinien być StatefulSetem, a kiedy Deploymentem? (Hint: cache-only vs source of truth)

## Bazowe demo (jeśli to twój pierwszy StatefulSet)

Plik `nginx.statefulset.yaml` to prostszy przykład — 5 replik nginx z dedykowanym storage per Pod. Spójrz na różnicę vs Deployment:

- Pody startują **sekwencyjnie** (`nginx-stsf-0` → Ready → `nginx-stsf-1` → Ready → ...)
- Pod ma **stałe imię** (po `delete pod` wraca z tym samym numerem)
- Z innego Pod-a możesz wywołać `curl nginx-stsf-1.stsf-service` — DNS per Pod
- `scale --replicas=2` usuwa Pod **z najwyższym ordinal** (nie losowy)
