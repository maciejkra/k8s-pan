# Parallel Queue Job (consumer/producer)

## Cel
Zrealizować pattern **work queue** z K8s Job-ami — producer pisze zadania do Redis, wielu konsumentów (paralleli Job-ów) je przetwarza.

## Kontekst
Standardowy Job ma `completions: N` i `parallelism: M` — uruchamia M Pod-ów równolegle, każdy musi successful complete N razy łącznie.

**Work Queue pattern**: zewnętrzna kolejka (Redis, RabbitMQ, Kafka) trzyma zadania. Job uruchamia parallelizm worker-ów, każdy bierze zadanie, kończy gdy kolejka pusta.

Use cases: ETL pipelines, image processing batch, ML inference batch, hyperparameter sweep.

## Prereqs
- K3d/Kind cluster

## Zadanie

1. Postaw Redis (kolejka):
   ```bash
   kubectl apply -f redis.yaml
   ```

2. Producer Job (wkłada N zadań do kolejki):
   ```bash
   kubectl apply -f producer.job.yaml
   kubectl logs -f -l type=producer
   ```

3. Parallel consumer Job (kilka Pod-ów dzieli pracę):
   ```bash
   kubectl apply -f parallel.job.yaml
   kubectl get job
   kubectl logs -f -l type=consumer
   ```

4. Obserwuj jak konsumenci dzielą zadania (każde przetworzone tylko raz, pomimo wielu Pod-ów).

## Pytania kontrolne
1. Jak Job rozumie "completion"? (Hint: exit 0 z proc 1)
2. Dlaczego `completions: N` + `parallelism: M` z N=M oznacza "po jednym wykonaniu na każdy Pod"?
3. Co gdy worker pada w trakcie (np. OOM)? Kto re-trigger zadanie?
4. Work Queue vs IndexedJob (od K8s 1.24) — różnica w semantyce?

## Linki
- [Job patterns](https://kubernetes.io/docs/concepts/workloads/controllers/job/#job-patterns)
- [Parallel Processing using Work Queue](https://kubernetes.io/docs/tasks/job/coarse-parallel-processing-work-queue/)
