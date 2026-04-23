# Zadanie

## Część 1 — Deploy + weryfikacja metryk

1. Zaaplikuj manifesty:
   ```bash
   kubectl apply -f hpa/
   kubectl wait --for=condition=ready pod -l run=php-apache --timeout=30s
   ```

2. Sprawdź stan HPA — na początku metryki będą `<unknown>`, po ~30s pokażą wartość CPU:
   ```bash
   kubectl get hpa
   # NAME         REFERENCE               TARGETS         MIN  MAX  REPLICAS
   # php-apache   Deployment/php-apache   <unknown>/50%   1    10   1
   sleep 30
   kubectl get hpa
   # TARGETS: 1%/50% (idle CPU)
   ```

## Część 2 — Wygeneruj load (drugi terminal!)

**W OSOBNYM TERMINALU** (żeby nie blokować obserwacji):

```bash
kubectl run -i --tty load-generator --rm --image=busybox:1.37 --restart=Never -- \
  /bin/sh -c "while sleep 0.01; do wget -q -O- http://php-apache; done"
```

Lub background (w tym samym terminalu):
```bash
kubectl run load-generator --image=busybox:1.37 --restart=Never -- \
  /bin/sh -c "while sleep 0.01; do wget -q -O- http://php-apache; done" &
```

## Część 3 — Obserwacja scale-up

W **głównym** terminalu:
```bash
kubectl get hpa --watch
# Po ~30-60s: TARGETS rośnie, REPLICAS rośnie

# Równolegle:
kubectl get pods -w
# Nowe Pody php-apache-xxx pojawiają się
```

Zapisz: **do ilu replik** HPA doszedł? **W jakim czasie**? Czy osiągnął 50% CPU per Pod po skalowaniu?

## Część 4 — Scale-down

Zatrzymaj load (Ctrl+C w terminalu load-generator albo `kubectl delete pod load-generator`).

```bash
kubectl get hpa --watch
# Po ~60s (nasz scaleDown.stabilizationWindow) replicas zaczną spadać
# Do 1 dojdzie zwykle po 2-3 min (tempo -50% per 60s)
```

W domyślnym HPA scale-down byłby **5 minut** stabilization + -100% policy — tu jest szybszy dla nauki.

## Część 5 — Porównanie z domyślnym behavior

1. Usuń `spec.behavior` z `hpa.yaml`:
   ```bash
   kubectl patch hpa php-apache --type=json -p='[{"op":"remove","path":"/spec/behavior"}]'
   ```

2. Powtórz load + zatrzymanie. Ile teraz trwa scale-down?

## Pytania

1. **Wzór HPA**: `desiredReplicas = ceil(currentReplicas × currentMetric / targetMetric)` — zastosuj dla: 2 Pody × 150m avg CPU, targetCPU 50% każdego z `requests.cpu: 200m`. Ile replik?
2. **Dlaczego scale-down jest wolniejszy niż scale-up** by default? Co chroni ta asymmetria?
3. **`stabilizationWindowSeconds: 0`** dla scaleUp — kiedy to złe? (Hint: flapping dla metryk zmieniających się gwałtownie.)
4. Custom metrics w HPA — wymień 2 sposoby konsumpcji (adapter, provider).
5. **Bonus**: HPA na **memory** — czemu jest trudniejszy niż na CPU? (Hint: memory rzadko zwalnia sama, potrzebuje restartu.)
