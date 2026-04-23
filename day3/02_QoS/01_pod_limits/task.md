# Zadanie

1. Wdroż 3 Pody różnych QoS class:
   ```bash
   kubectl apply -f pod-guaranteed.yaml -f pod-burstable.yaml -f pod-besteffort.yaml
   kubectl wait --for=condition=ready pod/pod-guaranteed pod/pod-burstable pod/pod-besteffort --timeout=30s
   ```

2. Sprawdź klasy QoS:
   ```bash
   kubectl get pods -o custom-columns='NAME:.metadata.name,QOS:.status.qosClass'
   # Spodziewane:
   # NAME             QOS
   # pod-guaranteed   Guaranteed
   # pod-burstable    Burstable
   # pod-besteffort   BestEffort
   ```

3. Symuluj memory pressure — spróbuj alokować więcej niż limit w Burstable:
   ```bash
   kubectl exec pod-burstable -- sh -c "head -c 500m /dev/urandom > /tmp/big"
   # Pod 400Mi limit → OOMKilled
   kubectl get pod pod-burstable
   # STATUS: OOMKilled
   ```

4. Sprawdź events:
   ```bash
   kubectl describe pod pod-burstable | grep -A 5 "Last State\|Events"
   # Reason: OOMKilled
   ```

5. CPU throttling (nie OOM) — Pod Guaranteed z 100m limit:
   ```bash
   kubectl exec pod-guaranteed -- sh -c "for i in 1 2 3 4; do yes > /dev/null & done; sleep 5; cat /sys/fs/cgroup/cpu.stat 2>/dev/null || cat /sys/fs/cgroup/cpu/cpu.stat"
   # Zobacz pola throttled_time / nr_throttled
   ```

## Pytania

1. CPU throttling vs memory OOM — czemu różna reakcja? Dlaczego CPU się "dzieli w czasie" a memory nie?
2. Co jeśli klaster ma 8 CPU a Pod prosi `requests.cpu: 16`? Pod zostanie scheduled?
3. Dlaczego `Guaranteed` dla critical workloads (payments, session store)? Argument jest tylko o OOM czy jest coś więcej (`cpuManagerPolicy: static`)?
4. Co się dzieje jeśli WSZYSTKIE Pody w klastrze są BestEffort i pojawi się node pressure? Czy kubelet ma politykę "ostatniej szansy"?
5. **Bonus**: czy init container wlicza się do QoS class Poda? (Patrz D3/01)
