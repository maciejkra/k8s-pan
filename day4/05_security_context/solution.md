# Solution — 05_security_context

## Odpowiedzi

### allowPrivilegeEscalation: false
Ustawia bit `no_new_privs` na procesie. Nie pomoże nawet `setuid` binary (np. `sudo`, `passwd`). Praktycznie blokuje większość scenariuszy eskalacji wewnątrz kontenera.

### runAsNonRoot: true bez runAsUser
K8s wymusza, że proces **nie startuje jako root** — ale UID musi być zdefiniowany w obrazie (`USER` w Dockerfile). Jeśli obraz ma `USER root` (lub brak USER), Pod nie wystartuje:
```
container has runAsNonRoot and image has non-numeric user (root)
```

### NET_BIND_SERVICE
Capability potrzebne, żeby proces nie-root mógł słuchać na portach < 1024. Trzy opcje:
1. **Aplikacja słucha na > 1024** (8080, 9090) — najlepiej. Service redirectuje 80 → 8080.
2. **`capabilities.add: ["NET_BIND_SERVICE"]`** — dodaje konkretnie tę CAP.
3. **`setcap`** w Dockerfile na binarce — alternatywa do (2), ale CAP w obrazie.

W tym ćwiczeniu opcja 1 — `nginx-unprivileged` słucha na 8080.

### seccomp profiles
- **RuntimeDefault** — Docker/containerd default seccomp profile. Blokuje ~50 niepotrzebnych syscalls (np. `kexec_load`, `bpf` w niektórych wersjach). Bezpieczny default dla 99% workload.
- **Unconfined** — bez seccomp. Tylko jeśli aplikacja absolutnie potrzebuje rzadkiego syscall (np. niektóre debugger-y).
- **Localhost: profile.json** — custom profile (np. wygenerowany przez bane / oci-seccomp-bpf-hook na podstawie real workload). Najbezpieczniejszy — whitelist tylko tego, co aplikacja faktycznie używa.

## Walidacja

```bash
kubectl get pod pod-bad pod-hardened
kubectl exec pod-hardened -- whoami    # nginx (nie root)
kubectl exec pod-hardened -- touch /a  # Read-only file system
kubectl exec pod-hardened -- touch /tmp/a   # OK (emptyDir tmpfs)

# Capabilities porównanie
kubectl exec pod-bad -- grep CapEff /proc/self/status
# CapEff: 00000000a80425fb (default Docker set)
kubectl exec pod-hardened -- grep CapEff /proc/self/status
# CapEff: 0000000000000000
```

## Cross-link
- D4/02 (PSA) wymusza SecurityContext per namespace — bez tego SecurityContext zależy od dyscypliny dewelopera
- D1/06 (hardening) — non-root w obrazie, żeby Pod **mógł** użyć runAsNonRoot
- D4/09 (OPA/Gatekeeper) — może wymusić bardziej granularne reguły niż PSA (np. "no NET_RAW capability")
