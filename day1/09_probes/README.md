# 09 — Healthchecks: Liveness, Readiness, Startup probes

## Cel
Skonfigurować trzy typy probe i zrozumieć kiedy każdy z nich jest właściwy. Symulować awarię i obserwować reakcję K8s.

## Kontekst
K8s nie wie sam z siebie czy aplikacja działa poprawnie — Pod może być Running ale aplikacja zacięta (deadlock, OOM-soft). Probe to mechanizm gdzie kubelet pyta aplikację "żyjesz?".

Trzy rodzaje:

| Probe | Co robi gdy fail | Kiedy |
|---|---|---|
| **Liveness** | restartuje kontener | proces żyje ale zacięty (deadlock) |
| **Readiness** | usuwa Pod ze Service Endpoints (przestaje dostawać ruch) | aplikacja chwilowo niezdolna obsłużyć ruchu (warming up cache, lost DB connection) |
| **Startup** | "tłumi" Liveness/Readiness dopóki nie pass | wolno startująca aplikacja (Java z bigiem JVM warmup) |

Mechanizmy: HTTP GET, TCP socket, exec command, gRPC (od K8s 1.27+).

## Prereqs
- K3d/Kind cluster

## Zadanie

1. Wdroż Pod z trzema probe (manifest w katalogu — przed wykonaniem przeczytaj plik!):
   ```bash
   kubectl apply -f probes.yaml
   kubectl describe pod liveness-readiness | grep -A 5 "Liveness\|Readiness\|Startup"
   ```

2. Symuluj awarię — usuń plik `/tmp/healthy` w kontenerze:
   ```bash
   kubectl exec liveness-readiness -- rm /tmp/healthy
   kubectl get pod liveness-readiness -w
   # Po `failureThreshold` × `periodSeconds` Pod zostanie zrestartowany
   ```

3. Obserwuj events:
   ```bash
   kubectl describe pod liveness-readiness | tail -20
   ```

4. Zmień `initialDelaySeconds` w probe i obserwuj wpływ na restart count.

## Pytania kontrolne
1. Liveness=Readiness na tym samym endpoincie — antywzorzec? Dlaczego?
2. Kiedy nie ustawiać Liveness probe wcale? (Hint: restart nie naprawi problemu)
3. Startup probe — co rozwiązuje czego nie rozwiązują Liveness + `initialDelaySeconds`?
4. Czemu probe HTTP powinno być **lekkie** (nie sprawdzać DB)?

## Linki
- [Configure Liveness, Readiness and Startup Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [Pod lifecycle](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/)
