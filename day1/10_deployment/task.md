# Zadanie - Python + Redis na Kubernetes

Odtwórz aplikację Python + Redis (znaną z dnia 1) jako pełny deployment na K8s:

1. Stwórz **Deployment** dla `redis:alpine`.
2. Stwórz **Deployment** dla `krajewskim/python-api:new`.
3. Stwórz **Service** dla redis typu `ClusterIP` - **nie nazywaj go `redis`** (zobacz, że aplikacja korzysta ze zmiennej `REDIS_HOST`).
4. Stwórz **Service** dla python typu `NodePort` o nazwie `python-service`.
5. Ustaw env `LOG_LEVEL=DEBUG` oraz `REDIS_HOST` wskazujący na Service redis (dla python).
6. Pilnuj poprawnych portów: REDIS=6379, PYTHON-API=5002. Zadbaj o spójne labele.

Sprawdź, że działa:
```sh
curl <ip>:<port>/api/v1/info
curl -XPOST <ip>:<port>/api/v1/info
curl <ip>:<port>/api/v1/info
```

## Extra

* Python: readiness po TCP, liveness po HTTP `/healthz`
* Redis: readiness po TCP, liveness przez `redis-cli ping`
* Limit `revisionHistoryLimit` Deploymentu do `0`
* Wykonaj rolling update (zmień env), zobacz `rollout history`, zrób `rollout undo`.

> **Uwaga:** ten setup (Python + Redis) wraca w kolejnych ćwiczeniach Day 2:
> - **D2/02** CronJob — będzie automatycznie bił licznik tej apki
> - **D2/03** Volume — dodasz persistent volume do Redis
> - **D2/05** ConfigMap — przeniesiesz env-y do ConfigMap
> - **D2/08** StatefulSet — wymienisz Redis Deployment na StatefulSet z dedykowanym storage
>
> Nie usuwaj Deploymentu po ukończeniu — zostaje jako baza na cały Day 2.
