# Zadanie

## Część 1 — Init container czekający na Service

1. Wdroż Pod z init containerem czekającym na **Service `redis-service`**:
   ```bash
   kubectl apply -f initc.pod.yaml
   kubectl get pods myapp-pod
   # Spodziewane: STATUS: Init:0/1  (czeka na init container)
   ```

2. Sprawdź logi init containera:
   ```bash
   kubectl logs myapp-pod -c init-myservice -f
   # Spodziewane: "waiting for redis-service" co 2s
   ```

3. W drugim terminalu zaaplikuj zależność (Redis Deployment + Service):
   ```bash
   kubectl apply -f redis.yaml
   ```

4. Obserwuj logi init containera — powinien skończyć się sukcesem:
   ```bash
   # W terminalu z logami: nslookup success, init container exit 0
   kubectl get pods myapp-pod
   # Spodziewane: STATUS: Running
   ```

## Część 2 — Pełny lifecycle Poda

1. Wdroż `full_lifecycle.yaml`:
   ```bash
   kubectl apply -f full_lifecycle.yaml
   kubectl wait --for=condition=ready pod/lifecycle --timeout=30s
   ```

2. Odczytaj kolejność zdarzeń:
   ```bash
   kubectl exec lifecycle -- cat /loop/timing.txt
   # Spodziewane (kolejność):
   # <ts>: INIT
   # <ts>: START
   # <ts>: POST-START
   # <ts>: LIVENESS       (co 30s)
   # <ts>: READINESS      (co 30s)
   ```

3. Wywołaj preStop przez delete:
   ```bash
   kubectl delete pod lifecycle &
   # Natychmiast zanim zniknie (w 30s grace period):
   kubectl exec lifecycle -- cat /loop/timing.txt | grep PRE-STOP
   ```

## Pytania

- Jaka jest kolejność zdarzeń: `init`, `postStart`, `PostStart hook`, main container start? Dlaczego?
- Co się dzieje jeśli init container kończy się błędem (exit 1)? Jak wygląda retry policy?
- Kiedy **native sidecar** (K8s 1.29+) jest lepszy niż klasyczny container? Podaj 2 przykłady.
- Jak zmusić main container żeby ZACZEKAŁ na `postStart` (który w K8s jest async)?
- Czym różni się `livenessProbe` od `readinessProbe` w kontekście timing z `timing.txt`?
