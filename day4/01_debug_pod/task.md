# Zadanie

## Część 1 — Deploy distroless

```bash
kubectl apply -f scratch-deployment.yaml
kubectl wait --for=condition=ready pod -l app=distroless-app --timeout=30s
POD=$(kubectl get pods -l app=distroless-app -o jsonpath='{.items[0].metadata.name}')
echo "POD=$POD"
```

## Część 2 — Klasyczny exec PADA

```bash
kubectl exec -it "$POD" -- sh
# error: failed to exec: exec: "sh": executable file not found in $PATH
```

Distroless nie ma `sh` / `bash`. Koniec tradycyjnego debugowania.

## Część 3 — Ephemeral container (in-place debug)

```bash
# Wstrzykuje nowy kontener `netshoot` do istniejącego Pod-a
# --share-processes = możesz widzieć procesy main containera
kubectl debug -it "$POD" \
  --image=nicolaka/netshoot \
  --share-processes \
  --target=app    # docelowy kontener dla PID namespace

# W netshoot shell:
ps aux
# Widzisz /pause (main container distroless)

# Network debugging:
curl -v http://localhost:8080
ss -tlnp
nslookup distroless-app

# Network sniffing:
tcpdump -n port 8080 -c 5
```

Ephemeral container żyje tak długo jak Pod — nie można go usunąć, ale można ponownie wystartować `kubectl debug` z tym samym `--image`.

## Część 4 — Copy-to (klon z innym image)

```bash
# Kopia Pod-a z ubuntu image (main command zastąpiony)
kubectl debug -it "$POD" \
  --image=ubuntu:24.04 \
  --share-processes \
  --copy-to=debug-clone \
  -- bash

# Wewnątrz klonu:
apt-get update && apt-get install -y curl tcpdump strace -qq
curl -v http://distroless-app:8080

# Oryginał nadal działa:
# kubectl get pods → distroless-app-xxx Running, debug-clone Running
```

Cleanup:
```bash
kubectl delete pod debug-clone
```

## Część 5 — Debug profiles (K8s 1.30+)

```bash
# Bez capabilities (default)
kubectl debug -it "$POD" --image=nicolaka/netshoot --profile=restricted

# Z CAP_NET_ADMIN (dla tcpdump raw socket)
kubectl debug -it "$POD" --image=nicolaka/netshoot --profile=netadmin

# Pełne capabilities (tylko admin-level)
kubectl debug -it "$POD" --image=nicolaka/netshoot --profile=sysadmin
```

Sprawdź jakie capabilities dostałeś:
```bash
# W debug container shell:
grep CapEff /proc/self/status
# sysadmin: 0000003fffffffff (wszystko)
# netadmin: dodatkowy CAP_NET_ADMIN, CAP_NET_RAW
```

## Część 6 — Debug node (kubectl debug node)

```bash
NODE=$(kubectl get nodes -o name | head -1 | cut -d/ -f2)
kubectl debug node/"$NODE" -it --image=ubuntu:24.04

# W debug Pod:
chroot /host    # root filesystem node-a zamontowany w /host
cat /var/log/syslog | tail
systemctl status kubelet
exit
```

## Pytania

1. **Ephemeral container vs Copy-to** — wymień 3 sytuacje dla każdego.
2. **`--share-processes`** — co robi? Co się dzieje jeśli go nie dasz?
3. **Distroless vs scratch** — który jest "bardziej pusty"? Czy scratch ma cokolwiek poza binarką aplikacji?
4. **`kubectl debug node`** — jakie są bezpieczeństwowe ryzyka? (Hint: chroot na root filesystem node-a.)
5. **Bonus**: Czy ephemeral container może być dodany do Pod-a zarządzanego przez Kustomize/Helm bez zmiany source? (Tak — bo jest ephemeral, nie wchodzi do spec Poda widocznego dla controller.)
