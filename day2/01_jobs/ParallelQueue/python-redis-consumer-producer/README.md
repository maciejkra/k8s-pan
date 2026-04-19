# Python Redis Consumer/Producer (source code)

Source code dla Redis-based work queue z [`../README.md`](../README.md).

## Pliki

- **producer** — Python script wkładający N zadań do Redis list `tasks`
- **consumer** — Python script biorący zadanie z `tasks` (BLPOP), przetwarzający, kończący gdy kolejka pusta

## Build & push (jeśli modyfikujesz)

```bash
docker build -t <REGISTRY>/python-queue-worker:v1 .
docker push <REGISTRY>/python-queue-worker:v1

# Update image w producer.job.yaml i parallel.job.yaml
```

## Logika

**Producer** (raz uruchamiany jako Job):
```python
import redis
r = redis.Redis(host="redis")
for i in range(100):
    r.rpush("tasks", f"task-{i}")
```

**Consumer** (uruchamiany jako Job z `parallelism: 5`):
```python
import redis
r = redis.Redis(host="redis")
while True:
    task = r.blpop("tasks", timeout=10)
    if task is None:
        break       # kolejka pusta → exit 0 → Job liczy completion
    # process task
```

## Cross-link

- Pełne ćwiczenie: [`../README.md`](../README.md)
- Alternatywa K8s-natywna: Indexed Job od K8s 1.24 (każdy Pod dostaje swój index zamiast walczyć o queue)
