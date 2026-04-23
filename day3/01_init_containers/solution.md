# Solution — 01_init_containers

## Odpowiedzi

### Kolejność zdarzeń

```
1. kubelet pobiera obrazy init containers + main containers (parallel)
2. Init containers uruchamiane SEKWENCYJNIE (po kolei w kolejności z manifestu)
3. Każdy init container musi zakończyć się exit 0, inaczej restart Poda
4. Main containers uruchamiane RÓWNOLEGLE (wszystkie startują razem)
5. Dla każdego main container: postStart hook wywołany JEDNOCZEŚNIE ze startem
   (NIE przed — Pod może być w Running zanim postStart się skończy)
6. Liveness/readiness probes — po initialDelaySeconds
7. Przy delete Pod: preStop hook, potem SIGTERM (terminationGracePeriodSeconds=30s default)
```

W `timing.txt` widać: INIT < START < POST-START (postStart jest async → może pojawić się PO START), LIVENESS/READINESS co 30s.

### Init container fail

- Exit 1 w init container → Pod status `Init:Error` (lub `CrashLoopBackOff` po kilku próbach).
- Kubelet retry'uje zgodnie z `restartPolicy` Poda:
  - `Always` (default dla Deployment-backed) → nieskończone retry z exponential backoff (10s, 20s, 40s, …, max 5min)
  - `OnFailure` → podobnie
  - `Never` (typowe dla Job) → jeden raz, Pod w `Failed`

Debug: `kubectl logs pod/X -c init-container-name` + `kubectl describe pod X`.

### Native sidecar (1.29+)

Sidecar container to init container z `restartPolicy: Always`. Zalety nad klasycznym sidecar-container:

1. **Start PRZED main container** — sidecar (np. Vault Agent Injector, Envoy proxy, fluentbit log shipper) jest gotowy zanim aplikacja zacznie. W klasycznym wzorcu main i sidecar startują równocześnie → race condition.
2. **Koniec PO main container** — przy `SIGTERM` sidecar żyje dopóki main się nie zakończy, więc ostatnie logi/traces zostaną wysłane. Klasyczny sidecar może umrzeć równocześnie z main (race).

Przykłady:
- **Vault Agent sidecar** (D4/04 inject-pod) — z native sidecar Vault połączy się i prerenderuje secrets ZANIM main app zacznie czytać plik.
- **Envoy proxy** w service mesh (Istio/Linkerd, D4) — Envoy musi być gotowy do odbioru ruchu zanim aplikacja zacznie rozgłaszać endpoint.
- **Log shipper** (fluentbit) — z native sidecar ostatnie linie logów z main zostaną wysłane po `SIGTERM` main.

Skonfigurować: `initContainers` z `restartPolicy: Always`:
```yaml
initContainers:
- name: vault-agent
  image: hashicorp/vault:1.17
  restartPolicy: Always        # <-- key
  command: ['vault', 'agent', '-config=/etc/vault/config.hcl']
```

### Zmusić main żeby zaczekał na postStart

`postStart` jest **async** — Pod może przejść do Running zanim postStart się skończy. Workarounds:

1. **Przenieś logikę do init container** (rekomendowane) — init jest synchronous, 100% kończy się przed main.
2. **`startupProbe`** — probe który musi przejść zanim Pod zostanie ogłoszony Ready. Może testować warunek który postStart spełnia (np. plik istnieje).
3. **Lock file w shared volume** — main container w `command` czeka aż plik pojawi się; postStart tworzy plik po skończeniu:
   ```bash
   # main command: until [ -f /shared/ready ]; do sleep 1; done; exec myapp
   # postStart: touch /shared/ready
   ```
   Kruche — lepiej init container.

### Liveness vs readiness w timing.txt

- **Liveness** — jeśli fail → Pod **restart** (kubelet kills + recreate container).
- **Readiness** — jeśli fail → Pod **removed from Service endpoints** (nadal żyje, ale nie dostaje ruchu).

W `timing.txt` obie wpisują linię co 30s (bo obie `exec` succeed). Jeśli zmienisz `exec.command` na `['false']` dla liveness — zobaczysz restart Pod-a (timing.txt znika, bo emptyDir jest nowy).

## Walidacja

```bash
# Część 1
kubectl delete -f redis.yaml -f initc.pod.yaml   # cleanup
kubectl apply -f initc.pod.yaml
kubectl get pod myapp-pod
# STATUS: Init:0/1

kubectl apply -f redis.yaml
sleep 10
kubectl get pod myapp-pod
# STATUS: Running

# Część 2
kubectl apply -f full_lifecycle.yaml
kubectl wait --for=condition=ready pod/lifecycle --timeout=30s
kubectl exec lifecycle -- cat /loop/timing.txt
# 1715000000: INIT
# 1715000001: START
# 1715000001: POST-START
# 1715000031: LIVENESS
# 1715000031: READINESS
```

## Troubleshooting

### Init container zawisł w "waiting"

```bash
kubectl logs myapp-pod -c init-myservice
# "nslookup redis-service.default.svc.cluster.local"
```
Typowe przyczyny:
- Service jeszcze nie utworzony (`kubectl get svc redis-service`).
- CoreDNS nie działa (`kubectl get pods -n kube-system -l k8s-app=kube-dns`).
- Init używa złej namespace — skrypt `cat /var/run/.../namespace` zwraca `default`, jeśli Pod jest w innym NS to nie znajdzie.

### `timing.txt` nie pokazuje wszystkich zdarzeń

- **PRE-STOP brak** — pamiętaj że masz 30s grace period; szybki delete bez pauzy między `kubectl delete pod` a następnym `cat` może nie zdążyć pokazać.
- **POST-START po LIVENESS** — `postStart` jest async, czasem opóźniony. To nie bug.

## Cross-link

- D1/12 (multi-container Pod) — sidecar pattern vs init container
- D4/04 (Vault) — Vault Agent Injector używa init container w klasycznym trybie, sidecar w natywnym
- D3/02 (QoS) — init containers wliczają się do pod's QoS class (najwyższe wymagania wygrywają)
