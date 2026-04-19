# 08 — StatefulSet (bazy danych w K8s)

## Cel
Wdrożyć StatefulSet (nginx jako demo), zaobserwować różnicę względem Deployment: stable network identity, ordinal index, persistent storage per Pod.

## Kontekst
**StatefulSet** = workload kontroler dla aplikacji **stateful** (bazy danych, kolejki, distributed systems). Różnice względem Deployment:

| | Deployment | StatefulSet |
|---|---|---|
| Pod names | losowe sufiksy (`app-7c5d-x9p`) | uporządkowane (`app-0`, `app-1`, `app-2`) |
| Pod ordering | równoległe | sekwencyjne (Pod N czeka na N-1 Ready) |
| Pod IP | stabilny | stabilny + DNS per Pod (`pod-N.service.ns.svc`) |
| Storage | shared lub none | dedicated PVC per Pod (volumeClaimTemplates) |
| Scale down | losowy Pod | Pod z najwyższym ordinal |

Use cases: PostgreSQL, MySQL, MongoDB, Cassandra, Kafka, Elasticsearch, Redis Cluster.

**Ważne pytanie**: czy w ogóle uruchamiać bazy w K8s? (link niżej)

## Prereqs
- K3d/Kind cluster

## Zadanie

1. Wdroż StatefulSet:
   ```bash
   kubectl apply -f .
   kubectl get pods -w
   # nginx-stsf-0 → Ready → nginx-stsf-1 → Ready → nginx-stsf-2 → Ready (sekwencyjnie!)
   ```

2. Sprawdź stable network identity (DNS per Pod):
   ```bash
   kubectl exec -ti nginx-stsf-0 -- curl localhost
   kubectl exec -ti nginx-stsf-0 -- curl nginx-stsf-1.stsf-service
   kubectl exec -ti nginx-stsf-0 -- curl nginx-stsf-1.stsf-service.default.svc.cluster.local
   ```

3. Usuń pojedynczy Pod i obserwuj:
   ```bash
   kubectl delete pod nginx-stsf-1
   kubectl get pods -w
   # Wraca z **tym samym** imieniem (nginx-stsf-1)
   ```

4. Skala down:
   ```bash
   kubectl scale sts nginx-stsf --replicas=2
   # Usuwa nginx-stsf-2 (najwyższy ordinal)
   ```

5. PVC per Pod (jeśli volumeClaimTemplates są w manifeście):
   ```bash
   kubectl get pvc
   # Po jednym PVC dla każdego Pod
   ```

## Pytania kontrolne
1. Headless Service (`clusterIP: None`) jest **wymagane** dla StatefulSet — dlaczego?
2. Co się stanie gdy usunę cały StatefulSet? Czy PVC zostają?
3. StatefulSet vs operator (np. PostgreSQL Operator) — kiedy które?
4. Dlaczego **bazy danych w K8s** są kontrowersyjne? (Hint: trade-off)

## Linki
- [StatefulSet basics](https://kubernetes.io/docs/tutorials/stateful-application/basic-stateful-set/)
- [Cassandra w K8s tutorial](https://kubernetes.io/docs/tutorials/stateful-application/cassandra/)
- [Postgres Operator (Zalando)](https://github.com/zalando/postgres-operator)
- [DBs on K8s — Google blog](https://cloud.google.com/blog/products/databases/to-run-or-not-to-run-a-database-on-kubernetes-what-to-consider)
