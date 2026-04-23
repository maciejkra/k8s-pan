# 03 — Topology Spread Constraints

## Cel
Rozprasować repliki aplikacji równomiernie po różnych **domenach topologii** (zone, hostname, rack) — żeby utrata jednej domeny nie zabiła całej aplikacji.

## Kontekst
Default scheduler może umieścić wszystkie repliki na **jednym** node (lub w jednej zone) — greedy bin-packing. To źle dla availability: node pada → cała aplikacja down.

**TopologySpreadConstraints** = deklaracja "rozrzuć te Pody po <topology key> z max różnicą = maxSkew".

Przykład: `maxSkew: 1, topologyKey: topology.kubernetes.io/zone, whenUnsatisfiable: DoNotSchedule` = między dowolnymi dwoma zone różnica liczby Pod-ów ≤ 1.

Alternatywy dla high availability:
- `podAntiAffinity: preferredDuringScheduling...` — starszy, mniej elastyczny (tylko "unikaj", nie "rozrzuć")
- **Default Pod Topology Spread** (built-in od K8s 1.25) — scheduler respektuje built-in default constraints (rozrzut per zone + hostname) bez explicit spec

## Prereqs
- K3s / Kind / K3d cluster z **min. 3 node'ami** (inaczej `maxSkew: 1` trudny do wymuszenia)

## Pliki

- `tsc.pod.yaml` — Deployment z TSC na hostname + zone (pokazuje oba patterns)

## Zadanie

1. Zaaplikuj:
   ```bash
   kubectl apply -f tsc.pod.yaml
   kubectl wait --for=condition=available deployment/tsc-demo --timeout=60s
   ```

2. Sprawdź rozkład:
   ```bash
   kubectl get pods -l app=tsc-demo -o wide --no-headers | awk '{print $7}' | sort | uniq -c
   # Spodziewane: rozłożone po różnych NODE (max różnica=1)
   # Przy 3 node'ach i 5 replikach: 2-2-1 lub 1-2-2
   ```

3. **Eksperyment**: scale do 10 replik:
   ```bash
   kubectl scale deployment tsc-demo --replicas=10
   kubectl get pods -l app=tsc-demo -o wide --no-headers | awk '{print $7}' | sort | uniq -c
   # Przy 3 nodach: 4-3-3 lub 3-4-3 (maxSkew 1)
   ```

4. **whenUnsatisfiable**: zmień z `DoNotSchedule` na `ScheduleAnyway`, scale do 100, obserwuj:
   - `DoNotSchedule`: niektóre repliki Pending (scheduler nie łamie constraint)
   - `ScheduleAnyway`: wszystkie zescheduled, ale constraint może być naruszony (soft)

## Pytania

1. `topologyKey: zone` vs `topologyKey: kubernetes.io/hostname` — kiedy które? Który jest "silniejszy"?
2. `maxSkew: 1` + 3 nody + 10 replik — jakie rozłożenia są legalne?
3. TSC + podAntiAffinity na tym samym Podzie — czy się sumują? (Tak — oba są sprawdzane przy schedulingu.)
4. Built-in default TSC (od 1.25) — kiedy użyteczny bez explicit konfiguracji? (Hint: zero-config HA dla Deployment bez spec TSC.)
5. **Bonus**: `minDomains` (K8s 1.27+) — jak to zmienia zachowanie TSC?

## Linki
- [Topology Spread Constraints](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/)
- [Default PodTopologySpread plugin](https://kubernetes.io/docs/reference/scheduling/config/#scheduling-plugins)
