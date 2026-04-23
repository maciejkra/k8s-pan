# 01 — Debug Pod (ephemeral containers, kubectl debug)

## Cel
Zdebugować aplikację działającą w **distroless** / scratch image (bez shell, bez tcpdump, bez niczego). Użyć `kubectl debug` z ephemeral container i `--copy-to`.

## Kontekst
W produkcji obrazy distroless / scratch (D1/02 hardening) **nie mają shella**. To dobre dla bezpieczeństwa, ale frustrujące przy debugowaniu (`kubectl exec -it pod -- sh` → nie ma `sh`).

Dwa rozwiązania `kubectl debug`:

1. **Ephemeral container** (in-place) — wstrzykuje nowy kontener do działającego Pod-a. Współdzieli network namespace. Idealny gdy:
   - Pod jest produkcyjny i nie chcemy go restartować
   - Chcesz tylko sprawdzić ruch sieciowy / process list

2. **Copy-to** (kopia z modyfikacjami) — tworzy duplikat Pod-a z innym image (np. ubuntu). Original Pod nadal działa. Idealny gdy:
   - Potrzebujesz aktywnie debugować (uruchomić nowy proces zamiast main)
   - Chcesz inny SecurityContext (np. dodać CAP_SYS_PTRACE)

### Debug profile (K8s 1.30+)

`kubectl debug --profile=<name>` — predefined SecurityContext modifications dla typowych przypadków:
- **general** (default) — minimalne zmiany
- **baseline** — drop capabilities, non-root
- **restricted** — PSA-restricted compatible
- **netadmin** — CAP_NET_ADMIN + CAP_NET_RAW (dla tcpdump)
- **sysadmin** — pełne capabilities (tylko admin-level debug)

## Prereqs
- K3s / Kind / K3d cluster z K8s ≥1.25 (ephemeral containers stable)

## Pliki

- `scratch-deployment.yaml` — Deployment z distroless image + Service

## Zadanie

Patrz [`task.md`](./task.md).

## Linki
- [Debug Running Pod](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/#ephemeral-container)
- [nicolaka/netshoot](https://github.com/nicolaka/netshoot) — popularny debug image z mnóstwem narzędzi sieciowych
- [kubectl debug profiles](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/#debugging-with-a-copy-of-the-pod-while-changing-its-command)
