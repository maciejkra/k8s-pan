# Solution — 08_statefulsets

## Odpowiedzi

### Dlaczego `clusterIP: None` (headless Service)?

Zwykły Service ClusterIP (np. `redis-service`) przydziela wirtualny IP i load-balancuje między wszystkie matching Pody. Dla StatefulSetu tego NIE chcemy — chcemy adresować **konkretne repliki** po imieniu (np. "zapisz do lidera, czytaj z followerów").

**Headless Service** (`clusterIP: None`) nie ma VIP. Za to:
- DNS query `redis-headless.default.svc.cluster.local` zwraca **listę A-recordów wszystkich matching Pod IP**.
- Dodatkowo StatefulSet + headless daje **per-Pod DNS**: `redis-0.redis-headless.default.svc.cluster.local`, `redis-1.redis-headless....`, etc. Pod-specific DNS istnieje tylko wtedy, gdy StatefulSet ma `serviceName: redis-headless`.

W naszym setupie są **dwa** Service-y:
- `redis-headless` — clusterIP: None, dla per-Pod DNS (wymagane przez `serviceName`)
- `redis-service` — zwykły ClusterIP dla klientów (Python app). Load-balancuje po wszystkich replikach.

### Czym się różni stable network identity od zwykłego Service?

| | Service ClusterIP | Pod DNS w StatefulSet |
|---|---|---|
| Co rozwiązuje | nazwa Service → wirtualny IP | `pod-N.service` → IP konkretnego Poda |
| Load balancing | tak (kube-proxy) | nie, kieruje do konkretnego Poda |
| Po restarcie Poda | IP Service nie zmienia się | Pod IP się zmienia, ale DNS hostname nadal wskazuje nowy IP |
| Użycie | stateless apps | distributed systems (Redis Cluster, Cassandra, Kafka) wymagające "kto jest kim" |

Dla Redis Sentinel / Cluster / PostgreSQL Patroni — każda replika musi znać swoich partnerów po unikalnej nazwie. To daje właśnie StatefulSet + headless.

### Kiedy Redis StatefulSet, kiedy Deployment?

- **Deployment**: Redis jako cache. Dane są regenerowalne (z bazy). Replicas=1 albo N (master-less), restart = puste. Prostota.
- **StatefulSet**: Redis jako source of truth (session store, rate limit counter, job queue). Potrzebujesz AOF/RDB persistence i stabilnej tożsamości dla replication/sentinel. Survive restart.

Pytanie pomocne: "czy mogę usunąć tego Poda i uruchomić świeżego bez utraty danych istotnych dla biznesu?". Tak = Deployment. Nie = StatefulSet.

### PVC po scale-down — dlaczego nie usuwane?

**Celowe zachowanie do K8s 1.26**: PVC z `volumeClaimTemplates` przeżywały scale-down i delete StatefulSetu. Filozofia: dane są cenne, K8s raczej NIE usuwa niż ryzykuje utratę. Admin ręcznie `kubectl delete pvc`.

**Od K8s 1.27+ (beta) / 1.30+ (GA)**: pole `spec.persistentVolumeClaimRetentionPolicy`:
```yaml
spec:
  persistentVolumeClaimRetentionPolicy:
    whenDeleted: Delete    # albo Retain (default)
    whenScaled: Delete     # albo Retain (default)
```

W edukacji default (Retain) jest "bezpieczniejszy" — student nie traci danych przy eksperymencie.

## Walidacja

```bash
# Po apply redis.statefulset.yaml i po tym jak Python z D1/10 działa:
kubectl get pods -l app=redis
# NAME     READY  STATUS
# redis-0  1/1    Running

kubectl get svc | grep redis
# redis-headless  ClusterIP  None            <none>  6379/TCP
# redis-service   ClusterIP  10.96.x.y       <none>  6379/TCP

# Licznik przed restart
NODE_PORT=$(kubectl get svc python-service -o jsonpath='{.spec.ports[0].nodePort}')
curl -sX POST "http://localhost:$NODE_PORT/api/v1/info" >/dev/null
curl -s "http://localhost:$NODE_PORT/api/v1/info" | jq .counter
# 1

# Delete Redis Pod
kubectl delete pod redis-0
kubectl wait --for=condition=ready pod/redis-0 --timeout=60s

# Licznik po restart — przetrwał dzięki AOF + PVC
curl -s "http://localhost:$NODE_PORT/api/v1/info" | jq .counter
# 1 (dalej, bo AOF odtworzył stan z dysku)
```

## Troubleshooting

### Pody w Pending po scale-up
```bash
kubectl describe pod redis-1 | tail -20
```
Typowe:
- PVC Pending (brak PV lub StorageClass). Na K3s → `local-path`, Kind → `standard`. Sprawdź `kubectl get sc`.
- Węzeł nie ma miejsca. `kubectl top nodes`.

### AOF corruption po `kubectl delete pod --force`
```bash
kubectl logs redis-0 | grep "AOF\|corrupt"
```
Redis przy uszkodzonym AOF potrzebuje `redis-check-aof --fix /data/appendonly.aof`. Do nauki:
```bash
kubectl exec -it redis-0 -- redis-check-aof --fix /data/appendonlydir/appendonly.aof.1.base.rdb
```

### "Service nie rozwiązuje mi do Poda"
Headless Service z `selector` matchującym tylko część replik. Sprawdź:
```bash
kubectl get endpoints redis-headless
# Powinno pokazać wszystkie Pod IP
```

## Cross-link

- D3/09 (Node maintenance + PDB) — StatefulSet z PDB zabezpiecza quorum (np. `minAvailable: 2` dla 3-replika klastra Redis Sentinel).
- D3/06 (Scheduling) — `podAntiAffinity` na hostname żeby repliki StatefulSet nie lądowały na tym samym node.
- D4/04 (Vault) — Vault sam używa StatefulSet dla HA (3 repliki, Raft).
