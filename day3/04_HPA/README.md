# 04 — Horizontal Pod Autoscaler (HPA)

## Cel
Skalować automatycznie Deployment na podstawie zużycia CPU. Zaobserwować scale-up pod obciążeniem i scale-down po zatrzymaniu.

## Kontekst
**HPA** = kontroler zwiększający/zmniejszający `replicas` Deployment (lub StatefulSet) na podstawie metryk:
- **CPU/memory** (przez Metrics Server — D3/03)
- **Custom metrics** (przez Prometheus Adapter — D5/04)
- **External metrics** (np. SQS queue length — wymaga adapter)

Algorytm: `desiredReplicas = currentReplicas × (currentMetric / desiredMetric)`

Defaults:
- `--horizontal-pod-autoscaler-sync-period=15s` — częstotliwość sprawdzania
- `--horizontal-pod-autoscaler-downscale-stabilization=5m` — żeby nie flapowało (powolny scale-down)

**VPA (Vertical Pod Autoscaler)** = analogicznie ale zmienia **resources** (requests/limits) — patrz oddzielny komponent.
**Cluster Autoscaler / Karpenter** = dodaje/usuwa nody (D5/04 GPU + slajd prezentacji "GPU production practices").

## Prereqs
- K3d/Kind cluster z **metrics-server** (D3/03)
- Aplikacja `php-apache` (z manifestu w katalogu)

## Zadanie

1. Wdroż app i HPA:
   ```bash
   kubectl apply -f .
   kubectl get hpa
   # NAME       REFERENCE         TARGETS         MIN  MAX  REPLICAS
   # php-apache Deployment/...    <unknown>/50%   1    10   1
   ```

2. Wygeneruj load:
   ```bash
   kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- \
     /bin/sh -c "while sleep 0.01; do wget -q -O- http://php-apache; done"
   ```

3. W innym terminalu obserwuj:
   ```bash
   kubectl get hpa --watch
   kubectl get pods --watch
   # Repliki rosną
   ```

4. Zatrzymaj load (Ctrl+C). Po ~5 min replicas zaczną spadać.


## Linki
- [HPA walkthrough](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/)
- [Metrics Server](https://github.com/kubernetes-sigs/metrics-server)
- [HPA algorithm details](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/#algorithm-details)
