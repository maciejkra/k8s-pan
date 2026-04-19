# 01 — Init Containers

## Cel
Zrozumieć jak Init Containers przygotowują środowisko **przed** startem głównych kontenerów. Zaobserwować sequential execution.

## Kontekst
**Init container** = kontener który uruchamia się **przed** głównymi kontenerami Pod-a. Cechy:
- Uruchamiany **sekwencyjnie** (jeden po drugim, w kolejności z manifestu)
- Musi **zakończyć się sukcesem** (exit 0) żeby przejść do następnego / main containers
- Pad podczas init = restart całego Pod-a (z exponential backoff)
- Może mieć inne capabilities niż main containers (np. większe — żeby zrobić chmod, potem main bez)

Use cases:
- **Wait for dependency** — czekaj aż DB / Service jest dostępny
- **Schema migration** — DB migrate przed startem app
- **Fetch secrets** — pobierz konfigurację z external store
- **chmod/chown** — przygotuj uprawnienia volumes
- **Generate config** — stwórz plik konfiguracyjny z env vars

K8s 1.29+: native sidecar containers = init containers z `restartPolicy: Always` (D1/13).

## Prereqs
- K3d/Kind cluster

## Zadanie

1. Wdroż Pod z init containerem czekającym na Service `myservice`:
   ```bash
   kubectl apply -f initc.pod.yaml
   kubectl get pods myapp-pod
   # STATUS: Init:0/1   (czeka na init container)
   ```

2. Sprawdź logi init containera:
   ```bash
   kubectl logs myapp-pod -c init-myservice
   # nslookup myservice... waiting...
   ```

3. Zaaplikuj brakującą zależność (Service `myservice`):
   ```bash
   kubectl apply -f redis.yaml
   kubectl logs myapp-pod -c init-myservice
   # success!
   ```

4. Po sukcesie init contenera Pod przechodzi do Running:
   ```bash
   kubectl get pods myapp-pod
   # STATUS: Running
   ```

## Pytania kontrolne
1. Co się stanie gdy init container fail-uje?
2. Init containers vs Job (do migracji DB) — kiedy które?
3. Czy init container ma dostęp do secret/configmap volumes głównego Pod-a?
4. Jak debugować zawieszający się init container? (Hint: `kubectl logs -c <init-name>`)

## Linki
- [Init Containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/)
- [Patterns: init containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/#use-cases)
