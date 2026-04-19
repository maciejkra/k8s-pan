# Solution — 13_multi_container_pod

## Odpowiedzi

### Współdzielenie sieci
Każdy Pod ma **pause container** (infrastructure container), który tworzy network namespace. Wszystkie inne kontenery dołączają do **istniejącego** namespace przez `--net=container:pause-id`. Dlatego widzą ten sam interfejs sieciowy i `localhost`.

### Sidecar w CrashLoopBackOff
Pod pozostaje **NotReady** (jeśli ma `readinessProbe` na sidecar) lub **Running ale degraded**. Konsekwencje:
- Service nie kieruje ruchu (gdy NotReady)
- App pracuje, ale sidecar nie spełnia swojej roli (np. logi nie trafiają do centralnego systemu)
- Auto-restart: kubelet restartuje tylko padający kontener (nie cały Pod), z exponential backoff

### Sidecar vs DaemonSet dla logów
| | Sidecar (per-Pod) | DaemonSet (per-node) |
|---|---|---|
| Granularność | per aplikacja | wspólny dla wszystkich Podów na node |
| Zasoby | N × sidecar dla N replik | 1 instance per node |
| Konfiguracja | per aplikacja (różne formaty) | wspólny config |
| Shared logs | proste (volume) | musi czytać `/var/log/containers/` |
| Best dla | applikacja-specific transformations | uniform log shipping |

W praktyce: **DaemonSet** (Fluent Bit, Promtail) dla większości; **sidecar** tylko gdy aplikacja ma dziwny format logów wymagający parsowania per-instance.

### Native sidecar containers (K8s 1.29+)
Wcześniej: sidecar był "zwykłym" kontenerem — Pod terminuje gdy main container się skończy, ale sidecar może wisieć (problem dla Job).

K8s 1.29+ dodaje `restartPolicy: Always` w `initContainers`:
```yaml
spec:
  initContainers:
    - name: sidecar
      restartPolicy: Always         # dzięki temu jest "long-running init" = sidecar
      image: ...
```

Korzyści:
- Sidecar startuje **przed** main containers (init order guaranteed)
- Sidecar żyje dopóki main containers żyją
- Sidecar nie blokuje terminacji Joba

## Walidacja sidecar logging

```bash
$ kubectl logs multi-container -c log-shipper --tail=5
2026-04-17 10:30:01 [app] request processed
2026-04-17 10:30:03 [app] request processed
...
```

## Cross-link
- D3/01 init_containers — sequencing przed main containers
- D3/08 network_policy — można ograniczyć egress sidecara osobno (ale tylko per-Pod)
- D5/04 monitoring — sidecar Prometheus exporter to częsty pattern (zamiast adding `/metrics` endpoint w aplikacji)
