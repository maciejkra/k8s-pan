# Solution — 01_pod_limits

## Odpowiedzi

### CPU throttling vs memory OOM

- **CPU to shared resource** — jeden CPU core mogą równolegle używać 10 procesów (time-slicing). Kubelet ustawia `cpu.cfs_quota_us` w cgroup → kernel ogranicza ile czasu CPU Pod dostaje per okres (100ms). Gdy Pod chce więcej, kernel **wstrzymuje** proces, potem wznawia. Brak utraty danych.
- **Memory to zasób wyłączny** — raz przydzielone, nie można "podzielić w czasie". Gdy Pod prosi o więcej niż `limits.memory`, kernel OOM-killer zabija proces (Pod). Dane w RAM tracone.

Konsekwencja: dla CPU "over-limit" jest OK (performance drop). Dla memory "over-limit" = **crash**. Dlatego `limits.memory` zawsze ustawiaj z marginesem.

### Pod z requests.cpu=16 na 8-CPU klastrze

Pod pozostanie **Pending na zawsze**. Scheduler filtruje nody po `requests` — żaden node nie ma wolnych 16 CPU, więc nie ma fitu. `kubectl describe pod` pokaże: `0/N nodes are available: N Insufficient cpu.`

Praktyka: monitoruj Pending Pody (Alert `KubePodNotReady > 10m`); często oznacza undersized cluster albo zgubiony `requests` w manifeście.

### Guaranteed dla critical

Powody **poza OOM**:
1. **`cpuManagerPolicy: static` + Guaranteed pod z integer CPU requests** → kubelet pinuje Pod do konkretnego CPU core (CPU affinity). Brak context-switchingu = niższa latencja dla workloadów latency-sensitive (payment, DNS).
2. **Memory NUMA alignment** (K8s 1.25+) — `topologyManager` wybiera memory z tego samego NUMA node co CPU.
3. **Scheduler priorytet** — Guaranteed jest preferowany przy scheduling (mniej prawdopodobnie przesuwany w czasie preemption).
4. **Eviction ranking** — kubelet ma jasną hierarchię: BestEffort → Burstable (przekraczający requests) → Guaranteed (ostatni).

### Wszystkie Pody BestEffort + node pressure

Kubelet ma **eviction thresholds** (`--eviction-hard=memory.available<500Mi`). Gdy przekroczone:
1. Kubelet próbuje odzyskać memory — usuwa nieużywane kontenery, obrazy (`imagefs` gc).
2. Potem evict Pody — od **najgorszego** w rankingu do najlepszego. BestEffort → pierwsi.
3. W ramach BestEffort: **Pody używające najwięcej ponad requests (tu brak requests, więc używające najwięcej absolutnie)**.

Gdy wszystkie są BestEffort i wszystkie równie zgłodniałe — kubelet eviktuje "losowo" (w praktyce: w kolejności creation time). Bez `priorityClass` brak "złotego Poda" — klaster jest w klasie ekonomicznej.

### Init container + QoS

Tak — init containery wliczają się. QoS class Poda = **najwyższa** klasa potrzebna by obsłużyć wszystkie kontenery (init + main + sidecar). Jeśli jeden init container ma `requests=limits` a inne nie — Pod jest Burstable (bo nie wszystkie spełniają Guaranteed warunek).

Więc najprościej: jeśli chcesz Guaranteed, ustaw `requests=limits` na WSZYSTKICH kontenerach (init i main).

## Walidacja

```bash
kubectl apply -f pod-guaranteed.yaml -f pod-burstable.yaml -f pod-besteffort.yaml
sleep 3
kubectl get pods -o custom-columns='NAME:.metadata.name,QOS:.status.qosClass'
# pod-guaranteed   Guaranteed
# pod-burstable    Burstable
# pod-besteffort   BestEffort

# OOM demo
kubectl exec pod-burstable -- sh -c "head -c 500m /dev/urandom > /tmp/big" ; \
sleep 5 ; kubectl get pod pod-burstable
# STATUS: OOMKilled

# Throttling demo (wymaga cgroups v2 — większość nowoczesnych K8s)
kubectl exec pod-guaranteed -- cat /sys/fs/cgroup/cpu.stat 2>/dev/null | grep throttle
# throttled_time: <liczba> ns
```

## Troubleshooting

### QoS Class = `BestEffort` mimo że Pod ma resources

Sprawdź **wszystkie** kontenery (init + main + sidecar) — jeśli któryś nie ma `requests`, cały Pod leci do Burstable/BestEffort.

### Pod Pending z "Insufficient cpu/memory"

```bash
kubectl top nodes
kubectl describe node <node> | grep -A 20 "Allocatable\|Allocated"
```
Zobacz ile wolnego. Jeśli wszystko przydzielone → scale cluster albo tight resources.

## Cross-link

- D3/02/02 (LimitRange) — wymusza defaulty, żeby BestEffort Podów nie było przypadkiem
- D3/02/03 (ResourceQuota) — agregacja na namespace, nie per-Pod
- D3/07 (PriorityClass + preemption) — inna oś ranking Podów
- D4/05 (SecurityContext) — niezwiązane z QoS, ale oba tworzą "profil Pod-a"
