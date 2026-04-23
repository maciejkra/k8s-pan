# 01 — Init Containers

## Cel
Zrozumieć jak Init Containers przygotowują środowisko **przed** startem głównych kontenerów. Zaobserwować sequential execution + cały lifecycle Pod-a (init → postStart → probes → preStop).

## Kontekst
**Init container** = kontener który uruchamia się **przed** głównymi kontenerami Pod-a. Cechy:
- Uruchamiany **sekwencyjnie** (jeden po drugim, w kolejności z manifestu)
- Musi **zakończyć się sukcesem** (exit 0) żeby przejść do następnego / main containers
- Błąd podczas init = restart całego Pod-a (z exponential backoff)
- Może mieć inne capabilities / image / resources niż main containers (np. większe — żeby zrobić chmod, potem main bez)

Use cases:
- **Wait for dependency** — czekaj aż DB / Service jest dostępny
- **Schema migration** — DB migrate przed startem app
- **Fetch secrets** — pobierz konfigurację z external store (Vault init w D4/04)
- **chmod/chown** — przygotuj uprawnienia volumes
- **Generate config** — stwórz plik konfiguracyjny z env vars

K8s 1.29+: **native sidecar containers** = init containers z `restartPolicy: Always`. Sidecar startuje PRZED main containers i żyje do końca Poda. Cross-link D1/12.

## Prereqs
- K3s / Kind / K3d cluster

## Pliki w katalogu

| Plik | Co pokazuje |
|---|---|
| `initc.pod.yaml` | Init container czekający na Service (nslookup w pętli) |
| `redis.yaml` | Deployment + Service Redis, zależność dla initc.pod.yaml |
| `full_lifecycle.yaml` | Pełen cykl życia Poda — init → postStart → probes → preStop |

## Zadanie

Patrz [`task.md`](./task.md).

## Linki
- [Init Containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/)
- [Pod lifecycle](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/)
- [Patterns: init containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/#use-cases)
- [Sidecar containers](https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/)
