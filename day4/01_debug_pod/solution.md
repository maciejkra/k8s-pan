# Solution — 01_debug_pod

## Odpowiedzi

### Ephemeral vs Copy-to

**Ephemeral container — kiedy:**
1. **Produkcja, krótka diagnostyka** — Pod żyje dalej, tylko dodajesz sidecar dla `curl`/`ss`. Bez restart → bez downtime.
2. **Network debugging aktywnego workloadu** — `tcpdump` na żywym ruchu.
3. **Bez modyfikacji Poda** — nie ruszasz spec.containers[], nie ryzykujesz że Deployment się zrolluje.

**Copy-to — kiedy:**
1. **Pod pada przy starcie** — `--copy-to` pozwala zmienić `command:` na `sleep 3600`, żeby dostać szansę debugowania.
2. **Chcesz inny SecurityContext** — np. dodaj `CAP_SYS_PTRACE` dla `strace`. Ephemeral nie pozwala na to (dziedziczy z Poda).
3. **Chcesz testować fix** — klon z `--image=mojrepo/myapp:debug-fix` na żywo.

### `--share-processes`

Flaga włącza `shareProcessNamespace: true` — wszystkie kontenery Pod-a widzą sobie PID-y. Bez:
- Debug container widzi tylko swoje procesy (PID 1 = `bash`, nie `/pause` z main container).
- `ps aux` nic sensownego nie pokaże.

Z:
- `ps aux` pokazuje procesy WSZYSTKICH kontenerów w Pod-ie.
- `strace -p <pid-of-main-process>` działa (ephemeral widzi PID main).

Limitacja: `--share-processes` + istniejący Pod — niemożliwe (wymaga zmiany Pod spec). Dlatego dla ephemeral `kubectl debug` inferuje z `--target` pod-PID namespace.

### Distroless vs scratch

**scratch**: absolutnie pusty. Tylko Twoja binarka. Nic więcej — ani `ls`, ani libc, ani CA certs.

**distroless**: zawiera minimum runtime:
- `gcr.io/distroless/static` — tylko libc + CA certs + tzdata + netgroup. ~2MB.
- `gcr.io/distroless/base` — + libc6 (dla dynamic linking). ~20MB.
- `gcr.io/distroless/java` — + JRE. ~200MB.
- `gcr.io/distroless/python3` — + Python interpreter. ~50MB.

**Trade-off**: scratch jest najmniejszy, ale wymaga statycznej binarki (Go z `CGO_ENABLED=0`, Rust z musl target). Distroless "jest dobry default" dla większości języków.

### Debug node — bezpieczeństwowe ryzyka

`kubectl debug node/X` tworzy Pod z:
- `hostPath: /` mounted jako `/host`
- `hostPID: true`, `hostNetwork: true`
- `privileged: true`

To jest **praktycznie root na node**. Ryzyko:
1. **Dostęp do `/etc/kubernetes/admin.conf`** → root na całym klastrze (kubeadm).
2. **Dostęp do `/var/lib/kubelet`** → wszystkie Pod volumes (secrets zamontowane do innych Pod-ów).
3. **Dostęp do `/var/run/docker.sock`** (jeśli CRI to Docker) → uruchomienie privileged containerów poza K8s.
4. **`/sys/kernel/debug`** — kdbg, dmesg, eBPF programs.

Praktyka: `kubectl debug node` RBAC tylko dla platform-admin. Alerty na `pods/debug` verb w audit log.

### Ephemeral w Helm/Kustomize

Tak, bo ephemeralContainers są w **`status`**, nie w `spec` widoczny dla kontrolerów. Deployment controller NIE widzi ephemeral container, nie generuje nowego ReplicaSet.

Ale: po restart Pod (np. `kubectl rollout restart`) ephemeral znika. To faktycznie ephemeral.

## Walidacja

```bash
kubectl apply -f scratch-deployment.yaml
kubectl wait --for=condition=ready pod -l app=distroless-app --timeout=30s
POD=$(kubectl get pods -l app=distroless-app -o jsonpath='{.items[0].metadata.name}')

# Ephemeral debug
kubectl debug -it "$POD" --image=nicolaka/netshoot --share-processes --target=app -- ps aux
# Widzisz /pause (lub Twoja binarka) z main container

# Copy-to
kubectl debug -it "$POD" --image=ubuntu --share-processes --copy-to=debug-clone -- bash -c "echo hello"
kubectl delete pod debug-clone

# Node debug
NODE=$(kubectl get nodes -o name | head -1 | cut -d/ -f2)
kubectl debug node/"$NODE" -it --image=alpine -- ls /host
# bin boot etc ... (root filesystem noda)
```

## Troubleshooting

### `ephemeral containers are disabled`

K8s <1.25 ma feature gate. Dla 1.25+ ephemeral jest stable, zawsze włączone. Sprawdź:
```bash
kubectl version --short
```

### `kubectl debug` nie podłącza TTY

Dodaj `-it`. Bez tego komenda dostaje output, ale nie można wpisać komend.

### Debug Pod w CrashLoopBackOff po `--copy-to`

`--copy-to` z default command (brak override) = kopiuje original command. Jeśli original Pod padał → debug clone pada tak samo. Dodaj `-- bash -c "sleep 3600"` albo `-- sh -c "sleep 3600"`.

### `kubectl debug node` zwraca "pod cannot have hostNetwork"

Klaster ma PSA `enforce: baseline`/`restricted` na `default` NS. `kubectl debug node` tworzy Pod w `default` z hostPID/hostNetwork — blokowane. Obejście:
```bash
kubectl debug node/X -n kube-system --image=alpine   # kube-system ma domyślnie privileged PSA
```

## Cross-link

- D1/02 (secure image) — distroless jako target; debug jest flip-side hardening
- D4/05 (SecurityContext) — debug profile `restricted` == PSA restricted
- D4/02 (PSA) — może blokować `kubectl debug` Pod-y (dependent na mode)
- D5/02 (Monitoring) — alternatywa: Prometheus + Grafana do obserwacji zamiast ad-hoc debug
