# Solution — 08_falco

## Odpowiedzi

### eBPF vs kernel module

**eBPF (modern_ebpf)**: CO-RE (Compile Once, Run Everywhere) — jeden bytecode działa na wszystkich kernelach ≥5.8 z BTF. Bez instalacji driver. Restart Falco = natychmiast gotowe.

**eBPF (legacy `ebpf`)**: wymaga probe `.o` file matching kernel version. Falco pobiera z falcosecurity/libs przy starcie. Działa na starszych kernelach (4.14+) ale wolniej (JIT overhead).

**Kernel module (kmod)**: najwyższa wydajność, ale:
- Wymaga `falco-driver-loader` przy starcie → `apt-get install linux-headers-$(uname -r)` + kompilacja.
- Nie działa na **distroless** / **CoreOS** / **Talos** / **FlatCar** (brak apt).
- Ryzykowny dla stability — zły moduł = kernel panic.

Default w 2026 = `modern_ebpf` wszędzie gdzie kernel ma BTF.

### `--set-file customRules` vs kubectl apply ConfigMap

Chart Falco generuje własną ConfigMap (`falco-rules`) zawierającą **zarówno** default rules jak i custom z `values.customRules`. Ta ConfigMap jest mountowana do DaemonSet jako `/etc/falco/rules.d/`.

Gdy dasz `kubectl apply -f my-configmap.yaml` osobno:
- Stworzysz oddzielną ConfigMap (nie tę którą chart zna).
- DaemonSet NIE ma volume referującego Twoją ConfigMap.
- Trzeba ręcznie patchować DaemonSet `spec.template.spec.volumes` + `volumeMounts` → ale helm reconcile to nadpisze przy upgrade.

Dlatego: zawsze **through helm**. `--set-file` przy install/upgrade, albo `values.yaml`:
```yaml
customRules:
  custom-rules.yaml: |
    - rule: ...
```

### Priority levels w Falcosidekick

Falcosidekick ma routing per-severity:
```yaml
slack:
  webhookurl: "..."
  minimumpriority: "warning"   # tylko ≥ WARNING na Slack
pagerduty:
  routingkey: "..."
  minimumpriority: "critical"  # tylko CRITICAL/ALERT/EMERGENCY → PagerDuty (on-call)
elasticsearch:
  hostport: "..."
  minimumpriority: "debug"     # wszystko do archiwizacji
```

Dzięki temu: CRITICAL = pagework w nocy, WARNING = Slack channel, INFO = lokalne logi.

### Falco + K8s audit driver

Falco może równolegle czytać:
1. **Syscalls** (kernel events) — eBPF/kmod.
2. **K8s audit events** (co kubectl robi) — przez webhook configured w kube-apiserver.

Przykład reguły K8s audit:
```yaml
- rule: K8s - ConfigMap with sensitive patterns
  condition: ka.verb in (create, update) and ka.target.resource=configmaps
             and (ka.req.configmap.data contains "password=" or ka.req.configmap.data contains "secret=")
  output: "ConfigMap z sekretem w plaintext: %ka.target.namespace/%ka.target.name"
  priority: WARNING
  source: k8s_audit    # <-- drugi driver
```

Użycie: detekcja "ktoś właśnie wpisał hasło w ConfigMap" w klastrze — sposób na złą higienę zespołu, nie tylko na malware.

### eBPF JIT wyłączony

Falco używa eBPF programs interpretowanych w kernelu (JIT dla wydajności). Jeśli `kernel.unprivileged_bpf_disabled=1` i brak capability `CAP_BPF`, Falco nie zaload'uje programu.

Fix (dla klastra produkcyjnego z hardening):
```bash
# Na hostach:
echo "kernel.unprivileged_bpf_disabled=0" >> /etc/sysctl.d/99-falco.conf
sysctl -p /etc/sysctl.d/99-falco.conf
```

Albo: daj Falco DaemonSet `CAP_BPF` (przez securityContext). Mniej bezpieczne (Falco Pod mógłby ładować własne BPF programs).

Spectre/Meltdown: eBPF JIT jest wyłączony na niektórych hostach (`net.core.bpf_jit_harden=2`) — Falco nadal działa (interpreted mode), tylko wolniej.

## Walidacja

```bash
# Falco działa, custom rules loaded
kubectl -n falco logs -l app.kubernetes.io/name=falco --tail=100 | grep -Ei "rule.*custom|loaded"

# Trigger built-in (UWAGA: wymaga TTY — bez `-it` rule "Terminal shell" nie firuje)
kubectl apply -f trigger-pod.yaml
kubectl wait --for=condition=ready pod/innocent-app --timeout=30s
kubectl exec -it innocent-app -- sh
# W logach Falco: "Terminal shell in container" (Notice)
exit

# Trigger custom — /etc write
kubectl exec innocent-app -- sh -c "echo malicious >> /etc/hosts"
sleep 3
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=30 | grep -i "Custom rule"
# "Custom rule: zapis do /etc wewnątrz kontenera (user=root file=/etc/hosts proc=sh ...)"

# Trigger custom — egress 4444 (na Linux/x86; pomijaj na Docker Desktop arm64)
kubectl exec innocent-app -- sh -c "nc -w 2 192.0.2.5 4444 || true"
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=30 | grep -i "Podejrzane"
```

### Dlaczego `evt.type=open` nie wystarczy

Modern glibc i busybox NIE wywołują surowego `open(2)` — używają `openat(2)` (z `AT_FDCWD` jako pierwszy argument). Reguła z samym `evt.type=open` przepuści wszystko.

```bash
# Empiryczny dowód — strace busybox sh:
strace -f -e trace=open,openat sh -c "echo x >> /etc/passwd" 2>&1 | head -5
# openat(AT_FDCWD, "/etc/ld.so.cache", O_RDONLY|O_CLOEXEC) = 3
# openat(AT_FDCWD, "/lib/ld-musl-aarch64.so.1", ...) = 3
# openat(AT_FDCWD, "/etc/passwd", O_WRONLY|O_CREAT|O_APPEND, 0666) = 3
```

Reguła `evt.type in (open, openat, openat2, creat) and evt.is_open_write=true` pokrywa wszystkie warianty.

### Dlaczego `fd.sport` (NIE `fd.rport` ani `fd.lport`)

Falco semantyka FD network fields:

| Pole | Znaczenie |
|---|---|
| `fd.cport` | port klienta (strony inicjującej połączenie) |
| `fd.sport` | port serwera (strony przyjmującej połączenie) |
| `fd.lport` | port "lokalny" — perspektywa zależy od kontekstu obserwacji FD, **nieintuicyjnie odwrócona** dla niektórych eventów |
| `fd.rport` | port "zdalny" — analogicznie |

Dla outbound `connect` z kontenera do `1.2.3.4:4444`: kontener=client, destination=server.
- `fd.cport` = ephemeral source port
- **`fd.sport` = 4444 ← stabilne dopasowanie**
- `fd.lport`/`fd.rport` mogą być odwrócone w zależności od kierunku eventu (`evt.dir=<` vs `>`)

Empiryczny test debug rule pokazuje, że Falco DNS lookup raportuje `lport=53 sport=53` — server port pojawia się w obu polach, ale `cport`/`sport` są jednoznaczne.

## Troubleshooting

### `Falco daemonset pod CrashLoopBackOff`

```bash
kubectl logs -n falco <falco-pod> --previous
```
Typowe:
- `Failed to open bpf: Operation not permitted` — brak BPF capability. Fix: upgrade chart, ustaw `securityContext.capabilities.add: [BPF, PERFMON]`.
- `No such file or directory: /etc/falco/falco.yaml` — helm misconfig. Re-install z clean values.
- `Unknown driver kind "ebpf"` — dla nowszych chart wersji użyj `modern_ebpf`.

### Custom rules nie triggerują

```bash
# Sprawdź że reguła jest loaded
kubectl exec -n falco ds/falco -- cat /etc/falco/rules.d/custom-rules.yaml | head

# Sprawdź parsing errors
kubectl logs -n falco -l app.kubernetes.io/name=falco | grep -i "ruleset\|parse\|invalid"
```

Częste: złe indentowanie YAML w `--set-file` (tabs vs spaces).

### macOS arm64 + modern_ebpf — limitacje LinuxKit

LinuxKit kernel 6.12 na Docker Desktop arm64 ma **częściowe** wsparcie BPF tracepointów. Status zaobserwowany na Falco 0.43.1:

| Tracepoint | Status |
|---|---|
| `sys_enter_open`, `sys_enter_creat` | brak (`libbpf: failed to determine tracepoint`) — nie problem, glibc/busybox używają `openat` |
| `sys_enter_openat`, `sys_enter_openat2` | działa — reguły plikowe firują |
| `sys_enter_execve` | działa — reguła "Terminal shell in container" firuje (wymaga TTY) |
| `sys_enter_connect` (z host namespace) | działa — Falco daemon, falcoctl, kubelet są obserwowane |
| `sys_enter_connect` (z workload pod) | **NIE działa** — connect z `innocent-app` (testowane: nc, curl, wget) niewidoczny w buforze BPF |

**Workaround dla Części 4 (egress detection):** użyj klastra na Linux/WSL2/x86. Ćwiczenie Część 3 (`/etc` write) działa na arm64.

```bash
# Jeśli modern_ebpf nie startuje wcale (np. brak BTF):
# W logach: "Failed to open engine 'modern_ebpf': ...no BTF"
helm upgrade falco falcosecurity/falco --reuse-values --set driver.kind=ebpf
# Falco pobierze probe-file matching kernel, wolniej ale działa
```

### Customrule zbyt "gadająca" (false positive storm)

Dodaj exclude do listy:
```yaml
- list: allowed_etc_writers
  items: [apt-get, dpkg, rpm, yum, npm, pip, gem, cargo, systemd-tmpfiles, apk,
          <twój-allowed-proces>]
```

## Cross-link

- D4/06 (kube-bench) — static audit (CIS Benchmark); Falco to dynamic (runtime)
- D4/07 (Trivy) — CVE scan images + config; Falco wykrywa zachowanie w runtime
- D2/09 (DaemonSet) — Falco ships as DS, dokładnie jak node-exporter
- D5/02 (Monitoring) — Falco exposes Prometheus metrics (`falco_events_total`)
- Presentation slajd 50 (Falco) — pokazywany przez Maćka podczas D4
