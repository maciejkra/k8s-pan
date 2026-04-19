# 05 — SecurityContext

## Cel
Skonfigurować Pod / kontener z minimalnymi uprawnieniami: non-root user, drop wszystkich capabilities, read-only root FS, seccomp.

## Kontekst
SecurityContext to **per-Pod** lub **per-container** ustawienia bezpieczeństwa runtime. Działa **niezależnie** od PSA (D4/02) i hardeningu obrazu (D1/06):
- Hardening obrazu = obraz **może** działać bezpiecznie
- SecurityContext = obraz **musi** działać bezpiecznie
- PSA = na poziomie namespace **wymusza** SecurityContext

Najważniejsze pola:
- `runAsUser` / `runAsGroup` / `runAsNonRoot` — UID/GID procesu
- `allowPrivilegeEscalation: false` — żaden setuid binary nie eskaluje
- `readOnlyRootFilesystem: true` — / jest read-only, do zapisu trzeba volume
- `capabilities.drop: ["ALL"]` — startujemy bez żadnych Linux capabilities
- `capabilities.add: ["NET_BIND_SERVICE"]` — dodajemy tylko to, co konieczne
- `seccompProfile.type: RuntimeDefault` — kernel filter na syscalls

## Prereqs
- K3d cluster

## Zadanie

1. Wdroż "zły" Pod (root, full caps, RW FS):
   ```bash
   kubectl apply -f pod-bad.yaml
   kubectl exec -it pod-bad -- id
   # uid=0(root) gid=0(root)
   kubectl exec -it pod-bad -- touch /etc/passwd_test && echo "MOGE PISAC"
   ```

2. Wdroż "wzmocniony" Pod:
   ```bash
   kubectl apply -f pod-hardened.yaml
   kubectl exec -it pod-hardened -- id
   # uid=101(nginx) gid=101(nginx)
   kubectl exec -it pod-hardened -- touch /etc/passwd_test 2>&1 || echo "OK - readonly FS"
   ```

3. Sprawdź capabilities:
   ```bash
   kubectl exec -it pod-bad -- sh -c "grep CapEff /proc/self/status"
   kubectl exec -it pod-hardened -- sh -c "grep CapEff /proc/self/status"
   # Hardened: CapEff: 0000000000000000 (zero!)
   ```

4. Zobacz, jak nginx hardened nadal działa na porcie 80 (mimo dropped CAPs):
   ```bash
   kubectl exec -it pod-hardened -- nginx -t
   # Wskazówka: pod-hardened.yaml używa nginx-unprivileged który słucha 8080
   ```

5. **Bonus** — wdroż w namespace z PSA `restricted` (z D4/02):
   ```bash
   kubectl create ns secure --dry-run=client -o yaml | \
     kubectl label --local --dry-run=client -f - \
       pod-security.kubernetes.io/enforce=restricted -o yaml | \
     kubectl apply -f -
   kubectl apply -n secure -f pod-bad.yaml          # ZOSTANIE ODRZUCONY
   kubectl apply -n secure -f pod-hardened.yaml     # OK
   ```


## Linki
- [Configure SecurityContext](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/)
- [Linux capabilities cheatsheet](https://man7.org/linux/man-pages/man7/capabilities.7.html)
