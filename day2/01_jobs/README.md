# 01 — Jobs i wzorce paralelizmu

## Cel
Zrozumieć Job (jednorazowe zadanie) i jak K8s realizuje równoległe wykonywanie przez `parallelism`/`completions` oraz pattern Work Queue.

## Kontekst
**Job** = workload kontroler dla zadań które **kończą się** (w przeciwieństwie do Deployment — long-running). Po sukcesie Pod nie restartuje. Po failure — `restartPolicy` decyduje (Never / OnFailure).

Pola sterujące paralelizmem:
- **`completions: N`** — Job zakończony, gdy N Podów successful
- **`parallelism: M`** — równolegle do M Podów na raz
- **`backoffLimit`** — max retries przy failure (default 6)
- **`activeDeadlineSeconds`** — twardy timeout

Wzorce:
- **Single completion** (default `completions: 1`) — pojedyncze zadanie (DB migration)
- **Parallel completions, fixed count** (`completions: N, parallelism: M`) — N zadań rozdzielonych
- **Work Queue** (`completions: 1, parallelism: M`, queue zewnętrzna) — wielu konsumentów dzieli kolejkę

## Plan ćwiczeń

- [`ParallelCompletion/`](./ParallelCompletion/) — wzorzec "fixed count": N zadań, M równolegle
- [`ParallelQueue/`](./ParallelQueue/) — wzorzec "work queue" z Redis

## Linki
- [Jobs docs](https://kubernetes.io/docs/concepts/workloads/controllers/job/)
- [Job patterns](https://kubernetes.io/docs/concepts/workloads/controllers/job/#job-patterns)
- [Indexed Job (od K8s 1.24)](https://kubernetes.io/docs/concepts/workloads/controllers/job/#completion-mode)
