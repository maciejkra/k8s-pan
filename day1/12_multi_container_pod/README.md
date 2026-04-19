# 13 — Multi-container Pod (sidecar pattern)

## Cel
Zrozumieć kiedy umieścić więcej niż jeden kontener w Pod i zaimplementować klasyczny **sidecar logging pattern** (główna aplikacja + sidecar zbierający logi z shared volume).

## Kontekst
Pod może zawierać **wiele kontenerów** dzielących:
- **sieć** (ten sam IP, te same porty — komunikują się przez `localhost`)
- **wolumen** (shared filesystem)
- **lifecycle** (startują razem, padają razem)

To **NIE** zastępuje microservices. Multi-container Pod używa się dla **tightly coupled** procesów które muszą być na tym samym node:

| Pattern | Kiedy | Przykład |
|---|---|---|
| **Sidecar** | rozszerza funkcjonalność głównej aplikacji | log shipper, metrics scraper, certyfikat refresher |
| **Ambassador** | proxy dla głównej aplikacji | redis proxy, service mesh sidecar (Envoy w Istio) |
| **Adapter** | normalizacja outputu dla zewnętrznego konsumenta | format converter (np. `nginx logs → JSON for Elastic`) |
| **Init container** | przygotowanie state przed startem główniej aplikacji | DB migration, fetch secrets, wait for dependency |

Init containers są specjalnym przypadkiem (uruchamiają się **sekwencyjnie przed** main containers) — patrz `day3/01_init_containers`.

## Prereqs
- K3d cluster (`./setup-cluster.sh`)

## Zadanie

1. Wdroż Pod z dwoma kontenerami (app generujący logi + sidecar wysyłający na stdout):
   ```bash
   kubectl apply -f sidecar-logging.yaml
   kubectl get pod multi-container -o jsonpath='{.spec.containers[*].name}'
   # Output: app log-shipper
   ```

2. Sprawdź logi obu kontenerów osobno:
   ```bash
   kubectl logs multi-container -c app
   kubectl logs multi-container -c log-shipper
   ```

3. Zweryfikuj shared volume:
   ```bash
   kubectl exec multi-container -c app -- ls /var/log/app/
   kubectl exec multi-container -c log-shipper -- ls /var/log/app/
   # Te same pliki widoczne z obu stron
   ```

4. Zweryfikuj shared network (kontenery rozmawiają przez localhost):
   ```bash
   kubectl apply -f ambassador-redis.yaml
   kubectl exec ambassador-pod -c app -- sh -c "apk add --no-cache redis && redis-cli -h localhost ping"
   # PONG
   ```

5. Zobacz jak lifecycle jest wspólny — kill jeden kontener, drugi też restart:
   ```bash
   kubectl delete pod multi-container --grace-period=0 --force
   ```

## Pytania kontrolne
1. Dlaczego kontenery w Pod współdzielą sieć? (Hint: pause container)
2. Co się stanie jeśli sidecar pada (CrashLoopBackOff), a app działa?
3. Sidecar vs DaemonSet — kiedy które dla collection logów?
4. Native sidecar containers (K8s 1.29+) — co to dodaje?

## Linki
- [Multi-container Pods](https://kubernetes.io/docs/concepts/workloads/pods/#how-pods-manage-multiple-containers)
- [Sidecar containers (native, K8s 1.29+)](https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/)
- [Patterns by Bilgin Ibryam (Red Hat)](https://www.redhat.com/architect/distributed-design-patterns)
