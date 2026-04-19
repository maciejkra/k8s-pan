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
- Wdrożona aplikacja Python+Redis z **D1/10** (Python Deployment zostaje, Redis Deployment **wymieniamy** na StatefulSet)

## Zadanie

Patrz [`task.md`](./task.md). Główny scenariusz: **wymień Redis Deployment z D1/10 na Redis StatefulSet** z `volumeClaimTemplates` i AOF persistence (`redis.statefulset.yaml`). Bazowy `nginx.statefulset.yaml` służy jako prostsze demo zachowania (sekwencyjne start, per-Pod DNS, stable identity).

## Linki
- [StatefulSet basics](https://kubernetes.io/docs/tutorials/stateful-application/basic-stateful-set/)
- [Cassandra w K8s tutorial](https://kubernetes.io/docs/tutorials/stateful-application/cassandra/)
- [Postgres Operator (Zalando)](https://github.com/zalando/postgres-operator)
- [DBs on K8s — Google blog](https://cloud.google.com/blog/products/databases/to-run-or-not-to-run-a-database-on-kubernetes-what-to-consider)
