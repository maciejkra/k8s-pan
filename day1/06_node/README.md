# 06 — Inspekcja node'ów klastra

## Cel
Poznać komendy `kubectl get/describe node`, zrozumieć co jest wewnątrz node'a i jak sprawdzić na którym node działa konkretny Pod.

## Kontekst
Node = maszyna (VM lub bare-metal) na której uruchamiają się Pody. W K3d/Kind node to kontener Docker. W produkcji typowo VM w cloud (EC2, GCE) lub fizyczny serwer.

Każdy node uruchamia:
- **kubelet** — agent K8s (mówi do API serwera)
- **container runtime** (containerd, CRI-O)
- **kube-proxy** — networking dla Service IP

## Prereqs
- K3d/Kind cluster

## Zadanie

1. Lista node'ów:
   ```bash
   kubectl get nodes -o wide
   # Pokazuje IP, OS, kernel, container runtime version
   ```

2. Szczegóły jednego node'a:
   ```bash
   kubectl describe node <name>
   # Sekcje: Conditions, Capacity, Allocatable, Allocated resources, Events
   ```

3. Sprawdź na którym node działa konkretny Pod:
   ```bash
   kubectl get pod <pod-name> -o jsonpath='{.spec.nodeName}'
   # lub
   kubectl get pods -A -o wide
   ```

4. Wejście do node'a (K3d):
   ```bash
   docker exec -it k3d-training-agent-0 sh
   # Sprawdź uruchomione kontenery:
   crictl ps
   ```

5. Pokaż "wewnętrzne" kontenery na node'zie:
   ```bash
   kubectl get pods -A -o wide | grep <node-name>
   ```

## Pytania kontrolne
1. `Capacity` vs `Allocatable` na node — jaka różnica? (Hint: system reserved)
2. Co znaczy condition `MemoryPressure` lub `DiskPressure`? Jak K8s reaguje?
3. Co to jest `kubelet` i jakie ma odpowiedzialności?
4. Czy można uruchomić Pod bezpośrednio przez kubelet (bez API server)? (Hint: static pods)

## Linki
- [Nodes architecture](https://kubernetes.io/docs/concepts/architecture/nodes/)
- [Node pressure eviction](https://kubernetes.io/docs/concepts/scheduling-eviction/node-pressure-eviction/)
