# Zadanie

## Część 1 — Weryfikacja / instalacja

1. Sprawdź, czy metrics-server już działa:
   ```bash
   kubectl get deployment -n kube-system metrics-server
   # Jeśli istnieje → przejdź do Części 2
   # Jeśli NIE istnieje (typowo Kind) → krok 2
   ```

2. Install:
   ```bash
   kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
   ```

3. Patch args dla K3d / Kind (kubelet self-signed cert):
   ```bash
   kubectl patch deployment metrics-server -n kube-system --type=json \
     -p='[
       {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"},
       {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-preferred-address-types=InternalIP,Hostname,ExternalIP"}
     ]'
   ```

4. Czekaj aż Ready:
   ```bash
   kubectl wait --for=condition=available -n kube-system deploy/metrics-server --timeout=3m
   ```

## Część 2 — Verify działa

```bash
kubectl top nodes
# NAME                       CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
# k3d-training-server-0      45m          1%     600Mi           7%

kubectl top pods -A
# NAMESPACE     NAME                      CPU(cores)   MEMORY(bytes)
# kube-system   coredns-xxx               1m           15Mi
```

Jeśli zwraca `error: Metrics API not available` — czekaj jeszcze 30s (metrics-server zbiera próbki co 15s, potrzebuje 2 próbek).

## Pytania

1. Dlaczego metrics-server jest **wymagany** do działania HPA? (Hint: skąd HPA wie ile CPU używa Pod?)
2. Metrics-server nie magazynuje historii — co użyć jeśli chcesz "ile CPU Pod zużył 3 godziny temu"? (Cross-link D5/02)
3. `kubectl top pod X --containers` — co pokazuje?
4. Co to jest `node-exporter` (D2/09) i jak różni się od metrics-server?
5. **Bonus**: Pod z `Guaranteed` QoS zużywa 10% CPU. `kubectl top pod` pokazuje `cpu: 100m`. Jak policzyć `CPU%`?
