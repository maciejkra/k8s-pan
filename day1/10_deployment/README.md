# 11 — Deployment (rolling update, rollout history, rollback)

## Cel
Wdrożyć aplikację przez Deployment, skalować, wykonać rolling update, obserwować historię, rollback do poprzedniej wersji.

## Kontekst
**Deployment** to wrapper nad ReplicaSet (D1/10) dodający:
- **Rolling update** (default strategia) — stopniowa wymiana Pod-ów
- **Recreate** (alternatywa) — restart wszystkich naraz
- **Rollout history** — zapis poprzednich ReplicaSet-ów (default: ostatnie 10)
- **Rollback** — przywrócenie poprzedniej wersji (`kubectl rollout undo`)

99% aplikacji stateless używa Deployment. StatefulSet (D2/08) dla stateful, DaemonSet (D2/09) dla per-node agentów.

Szczegóły strategii wdrożeń: patrz [`day3/05_Canary/strategies.md`](../../day3/05_Canary/strategies.md).

## Prereqs
- K3d/Kind cluster

## Zadanie

### Wariant A — proste wdrożenie

1. Wdroż i sprawdź:
   ```bash
   kubectl apply -f deployment.yaml
   kubectl get all
   ```

2. Skala:
   ```bash
   kubectl scale deployment/nginx-deployment --replicas=0
   kubectl get all
   ```

### Wariant B — rolling update z env variable

1. Dodaj `env` list w `deployment.yaml` i zaaplikuj:
   ```bash
   kubectl apply -f deployment.yaml
   kubectl rollout status deployment/nginx-deployment
   ```

2. Dodaj adnotację z przyczyną zmiany (widoczne w history):
   ```bash
   kubectl annotate deployment/nginx-deployment kubernetes.io/change-cause="env updated"
   kubectl rollout history deployments/nginx-deployment
   kubectl rollout history deployment/nginx-deployment --revision=1
   kubectl rollout history deployment/nginx-deployment --revision=2
   ```

3. Sprawdź czy env zostało propagowane:
   ```bash
   POD=$(kubectl get pods -l app=myapp -o jsonpath='{.items[0].metadata.name}')
   kubectl exec -ti "$POD" -- env | grep TEST_ENV
   ```

### Wariant C — rollback

1. Rollback do poprzedniej wersji:
   ```bash
   kubectl rollout undo deployment/nginx-deployment
   kubectl annotate deployment/nginx-deployment kubernetes.io/change-cause="env removed"
   kubectl rollout history deployments/nginx-deployment
   kubectl exec -ti "$POD" -- env | grep TEST_ENV    # już nie ma
   ```

2. Rollback do konkretnej wersji:
   ```bash
   kubectl rollout undo deployment/nginx-deployment --to-revision=2
   kubectl exec -ti "$POD" -- env | grep TEST_ENV    # znowu jest
   ```

### Wariant D — skalowanie + endpoints

1. Skala i obserwuj Service endpoints:
   ```bash
   kubectl describe svc my-app-service
   kubectl scale deployment nginx-deployment --replicas=3
   kubectl describe svc my-app-service
   # Więcej Pod IP w Endpoints
   ```

### Debugging

```bash
kubectl logs -l app=myapp
POD=$(kubectl get pods -l app=myapp -o jsonpath='{.items[0].metadata.name}')
kubectl exec -ti "$POD" -- cat /etc/resolv.conf
kubectl exec -ti "$POD" -- curl my-app-service
kubectl get rs          # stare ReplicaSet-y dla rollback history
```


## Wyzwanie (task) — Python+Redis na K8s

Zbudować pełną aplikację Python+Redis z poprzednich ćwiczeń:

1. Deployment YAML dla `redis:alpine`
2. Deployment YAML dla `krajewskim/python-api:new`
3. Service dla redis z ClusterIP type (nie nazywaj go `redis`!)
4. Service dla python typu NodePort (nazwa: `python-service`)
5. Env `LOG_LEVEL=DEBUG` dla python
6. Env `REDIS_HOST` wskazujący na redis Service
7. Porty: REDIS=6379, PYTHON-API=5002
8. Właściwe labele

```bash
kubectl apply -f .
curl <ip>:<port>/api/v1/info
curl -XPOST <ip>:<port>/api/v1/info
curl <ip>:<port>/api/v1/info
```

**Extra**:
- Python: readiness → TCP port, liveness → HTTP `/healthz`
- Redis: readiness → TCP port, liveness → command `redis-cli ping`
- Limit deployment history do 0

## Linki
- [Deployment docs](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Deployment strategies comparison](../../day3/05_Canary/strategies.md)
