# Solution — 09_daemonsets

## Odpowiedzi

### Tolerations: Deployment vs DaemonSet

**Deployment**: scheduler szuka JAKIEGOŚ node pasującego; zwykle są to worker nody (bez taintów). Jeśli wszystkie workery są zajęte, Pod idzie do Pending — admin dodaje więcej pojemności albo skaluje w dół.

**DaemonSet**: kontroler tworzy Pod dla **każdego** node. Jeśli node ma taint i DS nie ma matching toleration — Pod NIE wystartuje na tym nodzie. Dla systemowych DS (log, metric, CNI) brak Poda na control-plane = niekompletna observability klastra.

Stąd `tolerations` dla `node-role.kubernetes.io/control-plane:NoSchedule` (i historyczny `master`) są standardem dla DS.

**Eksperyment bez tolerations na Kind (1 CP + 2 workerów):**
```bash
# Usuń tolerations z daemonset.yaml, re-apply
kubectl get pods -l app.kubernetes.io/name=node-exporter -o wide
# Widzisz tylko 2 Pody (na workers), brak na CP. Metryki CP są niewidoczne.
```

Na K3s/K3d bez taintów CP — DS i tak wyląduje na wszystkim.

### Ograniczenie do label `storage=local-ssd`

**Opcja 1: nodeSelector** (prostsze, ale tylko "musi mieć ten label"):
```yaml
spec:
  template:
    spec:
      nodeSelector:
        storage: local-ssd
```

**Opcja 2: affinity** (bardziej wyrażne, np. "preferuj" lub "musi mieć jeden z kilku"):
```yaml
spec:
  template:
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: storage
                    operator: In
                    values: [local-ssd, nvme]
```

### `OnDelete` vs `RollingUpdate`

| Strategy | Zachowanie | Kiedy |
|---|---|---|
| `RollingUpdate` (default) | po `kubectl apply` Pody zastępowane po jednym | 99% przypadków — zwykłe upgrade |
| `OnDelete` | po `kubectl apply` **nic** się nie dzieje; admin musi ręcznie `kubectl delete pod` żeby zobaczyć nowy image | krytyczne systemy gdzie chcesz precyzyjną kontrolę (CNI, storage) |

Przykład `OnDelete`: Cilium DS — admin NIE chce żeby rolling update CNI zakłócał ruch; robi drain + delete pod kontrolowanie per-node.

### GPU DaemonSet (DCGM exporter)

Dwa typowe wzorce:

**A. nodeSelector na labelu GPU Feature Discovery (GFD):**
```yaml
spec:
  template:
    spec:
      nodeSelector:
        nvidia.com/gpu.present: "true"
```

**B. Toleration dla GPU-only taintu** (jeśli masz dedykowany GPU node pool):
```yaml
spec:
  template:
    spec:
      tolerations:
        - key: nvidia.com/gpu
          operator: Exists
          effect: NoSchedule
      nodeSelector:
        nvidia.com/gpu.present: "true"
```

Cross-link: D5/04 fake-gpu-operator tworzy label `nvidia.com/gpu.product=Tesla-A100` — przykład jak DS DCGM celuje w to.

## Walidacja

```bash
# Dla prostego setup (K3d 2 workers):
kubectl get ds node-exporter
# NAME           DESIRED  CURRENT  READY  UP-TO-DATE  AVAILABLE  NODE SELECTOR  AGE
# node-exporter  2        2        2      2           2          <none>         3m

# Dla Kind (1 CP + 2 workers) — dzięki tolerations:
# DESIRED 3, READY 3

# Metryki
kubectl run curlt --rm -it --image=curlimages/curl --restart=Never -- \
  curl -s http://<node-ip>:9100/metrics | grep node_memory_MemAvailable_bytes
# node_memory_MemAvailable_bytes 3.2e+09
```

## Troubleshooting

### Pod DS w Pending z powodem FailedScheduling
```bash
kubectl describe pod node-exporter-xxx | grep -A 10 Events
# Często: "0/3 nodes are available: 1 node(s) had untolerated taint"
```
→ dodaj odpowiedni `tolerations` dla tego taintu.

### Port 9100 conflict (hostPort)
Jeśli na nodzie jest już inny proces na 9100 (np. bare-metal node-exporter), DS Pod utknie w `ContainerCreating` z "hostPort conflict". Fix: zmień `hostPort` na np. 9101 albo wyłącz `hostNetwork` (ale wtedy tracisz per-host metryki z host network stack).

### DS Pod nie startuje na Kind control-plane mimo tolerations
Kind 0.24+ ma `kubeadm.k8s.io/v1beta4` z domyślnymi `kubeadm`-style tolerations. Sprawdź:
```bash
kubectl get node kind-control-plane -o yaml | grep -A 5 taints
```
Może mieć dodatkowe tainty (`node.kubernetes.io/not-ready:NoExecute`) które DS musi tolerować.

## Cross-link

- D3/06 (Scheduling) — szersze omówienie taints, tolerations, node affinity
- D5/02 (Monitoring) — Prometheus Operator instaluje node-exporter DS automatycznie przez kube-prometheus-stack chart
- D5/04 (AI/GPU) — DCGM exporter DS dla GPU metryk
- D4/08 (Falco) — runtime security DS
