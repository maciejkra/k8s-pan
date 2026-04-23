# Zadanie

## Część 1 — podstawowe wdrożenie

1. Wdroż DaemonSet:
   ```bash
   kubectl apply -f daemonset.yaml
   kubectl get daemonset node-exporter
   ```

2. Sprawdź — jeden Pod na każdym node:
   ```bash
   kubectl get pods -l app.kubernetes.io/name=node-exporter -o wide
   # Spodziewane: NAME                  READY  NODE
   # node-exporter-xxxxx   1/1    k3d-training-agent-0
   # node-exporter-yyyyy   1/1    k3d-training-agent-1
   # (+ jeszcze jeden na control-plane jeśli używasz Kind)
   ```

3. Zweryfikuj że scraper działa:
   ```bash
   NODE=$(kubectl get pods -l app.kubernetes.io/name=node-exporter -o jsonpath='{.items[0].spec.nodeName}')
   kubectl debug node/$NODE --image=busybox -it -- wget -qO- http://localhost:9100/metrics | head -20
   # Spodziewane: metryki typu node_cpu_seconds_total, node_memory_MemAvailable_bytes
   ```

## Część 2 — dynamika nodów

1. (K3d) Dodaj nowy node:
   ```bash
   k3d node create extra --cluster training
   # lub dla Kind: regenerate cluster z dodatkowym worker w kind.config.yaml
   sleep 30
   kubectl get pods -l app.kubernetes.io/name=node-exporter -o wide
   # Nowy Pod DaemonSet pojawi się automatycznie
   ```

2. (K3d) Usuń node:
   ```bash
   k3d node delete extra
   kubectl get pods -l app.kubernetes.io/name=node-exporter -o wide
   # Pod DaemonSet zniknął z tym nodem
   ```

## Część 3 — update strategy

1. Zmień obraz (np. patch image tag):
   ```bash
   kubectl set image ds/node-exporter node-exporter=quay.io/prometheus/node-exporter:v1.8.2
   kubectl rollout status ds/node-exporter
   ```

2. Obserwuj: Pody zastępowane po jednym (`RollingUpdate`). Ile Pod-ów widzisz w `Pending`/`ContainerCreating` naraz?

## Pytania

- Dlaczego DaemonSet potrzebuje `tolerations` a Deployment zwykle nie? Co się stanie jeśli usuniesz oba tolerations z naszego manifestu i odpalisz na Kind?
- Jak byś ograniczył DaemonSet tylko do nodów z labelem `storage=local-ssd`? (hint: `nodeSelector` albo `affinity`)
- Kiedy wybrać `updateStrategy: OnDelete` zamiast domyślnego `RollingUpdate`?
- DaemonSet dla GPU monitoringu (DCGM exporter — D5/02/04) — jak byś go ograniczył do nodów z GPU?
