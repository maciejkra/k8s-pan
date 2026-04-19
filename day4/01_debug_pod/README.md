# 01 — Debug Pod (ephemeral containers, kubectl debug)

## Cel
Zdebugować aplikację działającą w **distroless** / scratch image (bez shell, bez tcpdump, bez nicze). Użyć `kubectl debug` z ephemeral container i `--copy-to`.

## Kontekst
W produkcji obrazy distroless / scratch (D1/06 hardening) **nie mają shella**. To dobre dla bezpieczeństwa, ale frustrujące przy debugowaniu (`kubectl exec -it pod -- sh` → nie ma `sh`).

Dwa rozwiązania `kubectl debug`:

1. **Ephemeral container** (in-place) — wstrzykuje nowy kontener do działającego Pod-a. Współdzieli network namespace. Idealny gdy:
   - Pod jest produkcyjny i nie chcemy go restartować
   - Chcesz tylko sprawdzić ruch sieciowy / process list

2. **Copy-to** (kopia z modyfikacjami) — tworzy duplikat Pod-a z innym image (np. ubuntu). Original Pod nadal działa. Idealny gdy:
   - Potrzebujesz aktywnie debugować (uruchomić nowy proces zamiast main)
   - Chcesz inny SecurityContext (np. dodać CAP_SYS_PTRACE)

## Prereqs
- K3d/Kind cluster

## Zadanie

1. Wdroż celowo distroless deployment:
   ```bash
   kubectl apply -f scretch-deployment.yaml
   POD=$(kubectl get pods -l app=scretch -o jsonpath='{.items[0].metadata.name}')
   ```

2. Spróbuj klasycznie:
   ```bash
   kubectl exec -it "$POD" -- sh
   # error: exec: "sh": executable file not found in $PATH
   ```

3. **Opcja 1: ephemeral container** (network-shared sidecar):
   ```bash
   kubectl debug -it "$POD" --image=nicolaka/netshoot -- tcpdump -n port 8080
   # Widzimy ruch HTTP do main containera
   ```

4. **Opcja 2: copy-to** (klon z innym image):
   ```bash
   kubectl debug -it "$POD" --image=ubuntu --share-processes --copy-to=myapp-debug
   # Tworzy nowy Pod 'myapp-debug' z ubuntu jako image, ale tymi samymi volumes/env
   # Możemy "widzieć" procesy oryginału przez --share-processes
   ```

5. Sprzątnij debug klon:
   ```bash
   kubectl delete pod myapp-debug
   ```

## Pytania kontrolne
1. Ephemeral containers wymagają jakiego K8s feature gate? (Hint: GA od 1.25)
2. Dlaczego `--share-processes` w copy-to? Co to umożliwia?
3. Czy ephemeral container może mieć inne SecurityContext niż main? (Hint: tak — to jego siła)
4. Best practice: `nicolaka/netshoot` vs `busybox` vs `ubuntu` jako debug image?

## Linki
- [Debug Running Pod](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/#ephemeral-container)
- [nicolaka/netshoot](https://github.com/nicolaka/netshoot) — popularny debug image z mnóstwem narzędzi sieciowych
