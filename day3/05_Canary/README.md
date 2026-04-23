# 05 — Canary deployment + przegląd strategii

## Cel
Wdrożyć **canary release** przez Gateway API `weightedBackendRefs` (Envoy Gateway z D2/07). Zrozumieć kiedy canary, kiedy inne strategie.

## Kontekst
Strategie wdrożeń = jak migrować od starej wersji do nowej bez downtime / z minimalnym ryzykiem:
1. **Recreate** — restart wszystkich Pod-ów (downtime)
2. **Rolling update** (default) — stopniowa wymiana
3. **Blue/Green** — atomic switch (2× zasoby)
4. **Canary** — % traffic na nową wersję, monitoruj, zwiększaj
5. **A/B testing** — routing per user (cookie/header)
6. **Shadow** — dublowanie ruchu (read-only test)

→ **Pełne porównanie wszystkich 6 strategii: [`strategies.md`](./strategies.md)**

W tym ćwiczeniu — **Canary przez Gateway API weighted routing** (cross-link D2/07 Envoy Gateway). Cel: zobaczyć jak HTTPRoute `backendRefs[].weight` dynamicznie zmienia rozkład ruchu.

## Prereqs
- K3s / Kind / K3d cluster
- **Gateway API z D2/07** zainstalowany i działający (`training-gateway` Gateway z listenerem HTTP:80)
- Gateway API `Programmed=True`:
  ```bash
  kubectl get gateway training-gateway
  # ADDRESS: ... PROGRAMMED: True
  ```

## Pliki

- `strategies.md` — teoria 6 strategii deploymentowych
- `solution/` — gotowe manifesty dla canary przez weighted HTTPRoute
  - `deployment-v1.yaml` — v1 (pkad:blue, 2 repliki)
  - `deployment-v2.yaml` — v2 (pkad:green, 1 replika)
  - `httproute-canary.yaml` — HTTPRoute z weight 70/30
- `canary-demo/` — **advanced bonus**: własna Go aplikacja z Dockerfile + Argo Rollouts deployment (dla zaawansowanych, poza main task)

## Zadanie

Patrz [`task.md`](./task.md).

## Linki
- [Container Solutions: K8s Deployment Strategies](https://github.com/ContainerSolutions/k8s-deployment-strategies)
- [Gateway API — Weighted Routing](https://gateway-api.sigs.k8s.io/guides/traffic-splitting/)
- [Argo Rollouts](https://argoproj.github.io/argo-rollouts/)
- [Flagger](https://flagger.app/)
- [Progressive Delivery podcast (Dan Lorenc)](https://www.youtube.com/results?search_query=progressive+delivery+kubernetes)
