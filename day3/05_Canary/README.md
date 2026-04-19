# 05 — Canary deployment + przegląd strategii

## Cel
Wdrożyć **canary release** ręcznie (dwa Deploymenty + Ingress weighted routing). Zrozumieć kiedy canary, kiedy inne strategie.

## Kontekst
Strategie wdrożeń = jak migrować od starej wersji do nowej bez downtime / z minimalnym ryzykiem:
1. **Recreate** — restart wszystkich Pod-ów (downtime)
2. **Rolling update** (default) — stopniowa wymiana
3. **Blue/Green** — atomic switch (2× zasoby)
4. **Canary** — % traffic na nową wersję, monitoruj, zwiększaj
5. **A/B testing** — routing per user (cookie/header)
6. **Shadow** — dublowanie ruchu (read-only test)

→ **Pełne porównanie wszystkich 6 strategii: [`strategies.md`](./strategies.md)**

W tym ćwiczeniu — **Canary ręcznie** (bez Argo Rollouts / Flagger). Cel: zobaczyć podstawowy mechanizm.

## Prereqs
- K3d/Kind cluster
- Ingress / Gateway (D2/07) — implementacja routingu

## Zadanie

### Wariant prosty (bez tooling)

1. Stwórz 2 Deployments w 2 różnych namespace:
   - `python-api` (v1) w namespace `prod`
   - `nginx` (v2) w namespace `canary`

2. Stwórz Ingress / HTTPRoute z weighted routing:
   - 70% ruchu → `python-api`
   - 30% ruchu → `nginx`

3. Test:
   ```bash
   for i in {1..100}; do curl -s api.127.0.0.1.nip.io | head -c 30; echo; done | sort | uniq -c
   # ~70 hits python-api, ~30 hits nginx
   ```

4. Stopniowo zwiększaj % nginx (50/50, 80/20, 100% nginx) — w produkcji tu byłaby pauza na monitoring metryk.

### Bonus — Argo Rollouts (rekomendowane w produkcji)

```bash
# install Argo Rollouts
helm install argo-rollouts argo/argo-rollouts -n argo-rollouts --create-namespace

# Rollout zamiast Deployment definiuje canary steps:
# steps:
#   - setWeight: 20
#   - pause: { duration: 5m }
#   - setWeight: 50
#   - pause: { duration: 5m }
#   - setWeight: 100
```

→ patrz `canary-demo/` w tym katalogu dla pełnego przykładu.

## Pytania kontrolne
1. Manual canary vs Argo Rollouts vs Flagger — kiedy które?
2. Jak automatycznie rollback gdy nowa wersja ma więcej błędów? (Hint: AnalysisRun)
3. Canary wymaga jakich metryk? (Hint: error rate, latency, custom business metric)
4. Można robić canary BEZ service mesh? (Hint: tak — Ingress weighted routing)

## Linki
- [Container Solutions: K8s Deployment Strategies](https://github.com/ContainerSolutions/k8s-deployment-strategies)
- [Argo Rollouts](https://argoproj.github.io/argo-rollouts/)
- [Flagger](https://flagger.app/)
- [`strategies.md`](./strategies.md) — pełne porównanie 6 strategii
