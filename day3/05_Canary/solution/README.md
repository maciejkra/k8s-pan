# Solution — Canary deployment z PVC

## Cel
Rozwiązanie task z [`../README.md`](../README.md): Canary release z dwoma deploymentami i PVC.

## Pliki

- `old-canary.deployment.yaml` — stara wersja (production)
- `canary.deployment.yaml` — nowa wersja (canary, np. 30% ruchu)
- `pvc.yaml` — PVC współdzielone między starą a nową wersją (jeśli wymaga shared state)

## Krok po kroku

1. Zaaplikuj PVC:
   ```bash
   kubectl apply -f pvc.yaml
   ```

2. Zaaplikuj starą wersję (100% ruchu na początku):
   ```bash
   kubectl apply -f old-canary.deployment.yaml
   ```

3. Zaaplikuj canary (np. 1 replikę, podczas gdy stara ma 9 → automatycznie ~10% ruchu na canary jeśli Service używa label selector matchującego oba):
   ```bash
   kubectl apply -f canary.deployment.yaml
   ```

4. Test:
   ```bash
   for i in {1..100}; do curl -s http://<service>/version; echo; done | sort | uniq -c
   ```

5. Stopniowo zwiększaj canary replicas (1 → 2 → 5 → 10) i zmniejszaj old → 0.

## Kluczowe punkty

- Canary i prod używają **tego samego Service** (selector `app=myapp`), różnią się labelem `version` (v1 / v2)
- Procent ruchu = liczba replik / total
- Dla precyzyjnego routingu (10%, 30%, 50%) używaj **Ingress canary** lub **Argo Rollouts** (cross-link D3/05 strategies.md)
- PVC `accessModes: ReadWriteMany` jeśli oba deployments mają pisać; `ReadWriteOnce` + canary NA TYM SAMYM NODE jeśli pojedynczy reader
