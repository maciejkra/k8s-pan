# Solution — Python + Redis stack

## Cel
Rozwiązanie wyzwania z [`../README.md`](../README.md): pełen Python + Redis na K8s.

## Pliki

- `redis-deployment.yaml` — Deployment Redis z `redis:alpine`
- `redis-svc.yaml` — Service ClusterIP dla Redis (port 6379)
- `python-deployment.yaml` — Deployment Python API z env `LOG_LEVEL=DEBUG` i `REDIS_HOST`
- `python-svc.yaml` — Service NodePort dla Python (port 5002)

## Walidacja

```bash
kubectl apply -f .
kubectl wait --for=condition=ready pod -l app=python --timeout=2m
kubectl wait --for=condition=ready pod -l app=redis --timeout=2m

NODE_PORT=$(kubectl get svc python-service -o jsonpath='{.spec.ports[0].nodePort}')
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

curl http://$NODE_IP:$NODE_PORT/api/v1/info
curl -XPOST http://$NODE_IP:$NODE_PORT/api/v1/info
curl http://$NODE_IP:$NODE_PORT/api/v1/info
# counter rośnie
```

## Kluczowe punkty

1. Service Redis nie nazywa się `redis` (kolizja z built-in env vars `REDIS_*` w niektórych obrazach)
2. `REDIS_HOST` wskazuje na nazwę Service Redis (DNS resolution wewnątrz klastra)
3. Etykiety używane konsekwentnie (`app: python`, `app: redis`)
4. Limit history (`spec.revisionHistoryLimit: 0`) — produkcyjnie typowo 5-10, tu 0 dla nauki
