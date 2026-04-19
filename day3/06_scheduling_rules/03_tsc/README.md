# 03 — Topology Spread Constraints

## Cel
Rozprasować repliki aplikacji równomiernie po różnych **domenach topologii** (zone, hostname, rack) — żeby utrata jednej domeny nie zabiła całej aplikacji.

## Kontekst
Default scheduler może umieścić wszystkie repliki na **jednym** node (lub w jednej zone) — greedy bin-packing. To źle dla availability: node pada → cała aplikacja down.

**TopologySpreadConstraints** = deklaracja "rozrzuć te Pody po <topology key> z max różnicą = maxSkew".

Przykład: `maxSkew: 1, topologyKey: zone, whenUnsatisfiable: DoNotSchedule` = między dowolnymi dwoma zone różnica liczby Pod-ów ≤ 1.

Alternatywy dla high availability:
- `podAntiAffinity: preferredDuringScheduling...` — starszy, mniej elastyczny
- **PodTopologySpread** (built-in od K8s 1.25) — scheduler respektuje built-in default constraints (rozrzut per zone + hostname)

## Prereqs
- K3d/Kind cluster z **min. 3 node'ami** (inaczej maxSkew=1 ciężko wymusić)

## Zadanie

1. Zaaplikuj Pod z topology constraint:
   ```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: mypod
     labels: { foo: bar }
   spec:
     topologySpreadConstraints:
       - maxSkew: 1
         topologyKey: kubernetes.io/hostname
         whenUnsatisfiable: DoNotSchedule
         labelSelector:
           matchLabels: { foo: bar }
     containers:
       - name: pause
         image: registry.k8s.io/pause:3.9
   ```

2. Wdroż kilka (5) replik z tą etykietą. Sprawdź:
   ```bash
   kubectl get pods -l foo=bar -o wide
   # Spodziewane: rozłożone po różnych hostname (nodeName)
   ```

3. **Eksperyment**: scale do 10 replik gdy masz 3 nody. `maxSkew: 1` wymaga 3-4-3 rozłożenia (lub podobnie).

4. **whenUnsatisfiable: DoNotSchedule vs ScheduleAnyway**:
   - `DoNotSchedule` — Pod Pending gdy constraint nie da się spełnić
   - `ScheduleAnyway` — soft preference, scheduler zrobi co może, ale zaplanuje w każdym razie

## Pytania kontrolne
1. `topologyKey: zone` vs `topologyKey: kubernetes.io/hostname` — kiedy które?
2. `maxSkew: 1` + 3 nody + 10 replik — jakie rozłożenia są legalne?
3. TSC + podAntiAffinity na tym samym Podzie — czy się sumują?
4. Built-in default TSC (od 1.25) — kiedy użyteczne bez explicit konfiguracji?

## Linki
- [Topology Spread Constraints](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/)
- [PodTopologySpread plugin](https://kubernetes.io/docs/reference/scheduling/config/#scheduling-plugins)
