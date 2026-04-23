# Zadanie

## Część 1 — Pod bez securityContext (baseline "zły")

```bash
kubectl apply -f pod-bad.yaml
kubectl wait --for=condition=ready pod/pod-bad --timeout=30s

# Zobacz co możesz zrobić jako root
kubectl exec pod-bad -- whoami
# root

kubectl exec pod-bad -- id
# uid=0(root) gid=0(root) groups=0(root)

kubectl exec pod-bad -- touch /etc/hacked && echo "MOGE PISAC"
# MOGE PISAC

kubectl exec pod-bad -- grep CapEff /proc/self/status
# CapEff: 00000000a80425fb (dużo capabilities)
```

## Część 2 — Hardened Pod

```bash
kubectl apply -f pod-hardened.yaml
kubectl wait --for=condition=ready pod/pod-hardened --timeout=30s

# Non-root
kubectl exec pod-hardened -- whoami
# nginx (lub inny nonroot user)

# Read-only root filesystem
kubectl exec pod-hardened -- touch /etc/hacked
# Read-only file system

# Ale /tmp jest writable (emptyDir tmpfs)
kubectl exec pod-hardened -- touch /tmp/ok
# OK

# Wszystkie capabilities dropped
kubectl exec pod-hardened -- grep CapEff /proc/self/status
# CapEff: 0000000000000000
```

## Część 3 — Porównanie

```bash
# Obie w tabelce:
echo "=== pod-bad ===" ;
kubectl exec pod-bad -- grep -E '^(Uid|Gid|CapEff)' /proc/self/status
echo "=== pod-hardened ===" ;
kubectl exec pod-hardened -- grep -E '^(Uid|Gid|CapEff)' /proc/self/status
```

## Część 4 — Bonus: restricted NS

Stwórz NS z PSA `enforce: restricted`, wdróż `pod-bad.yaml` tam — powinno być odrzucone. Hardened — OK.

```bash
kubectl create namespace secure
kubectl label namespace secure pod-security.kubernetes.io/enforce=restricted
kubectl apply -n secure -f pod-bad.yaml
# Error: pods "pod-bad" is forbidden: violates PodSecurity "restricted:latest"
```

## Pytania

1. **`allowPrivilegeEscalation: false`** — co to technicznie znaczy? Dlaczego `runAsNonRoot` nie wystarczy?
2. **`runAsNonRoot: true` bez `runAsUser`** — co się stanie jeśli obraz ma `USER root` w Dockerfile?
3. **`NET_BIND_SERVICE`** — kiedy potrzebne? Jakie alternatywy?
4. **seccomp profiles**: `RuntimeDefault` vs `Localhost` vs `Unconfined` — kiedy który?
5. **Bonus**: `readOnlyRootFilesystem: true` + aplikacja chce zapisywać state — jak to pogodzić? (Hint: emptyDir volume mount + writable subpath.)
