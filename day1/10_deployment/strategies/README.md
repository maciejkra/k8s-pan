# Strategies — Recreate vs Slow Rolling Update

## Cel
Porównać dwie konkretne strategie wdrożenia: `Recreate` (z downtime) i `slow-update` (rolling z restrykcyjnymi `maxSurge`/`maxUnavailable`).

## Kontekst
Manifest `recreate.yaml` używa `spec.strategy.type: Recreate` — wszystkie Pody są zatrzymywane PRZED utworzeniem nowych. Downtime gwarantowany.

Manifest `slow-update.yaml` używa `RollingUpdate` z `maxSurge: 1` i `maxUnavailable: 0` — wymiana po jednym Podzie naraz, zawsze 100% dostępne. Wolne ale bezpieczne.

Pełne porównanie 6 strategii: [`../../day3/05_Canary/strategies.md`](../../day3/05_Canary/strategies.md).

## Zadanie

1. Wdroż Recreate i obserwuj:
   ```bash
   kubectl apply -f recreate.yaml
   # zmień image w manifeście
   kubectl apply -f recreate.yaml
   kubectl get pods -w
   # Wszystkie Terminating → potem nowe
   ```

2. Wdroż slow-update i obserwuj:
   ```bash
   kubectl apply -f slow-update.yaml
   # zmień image
   kubectl apply -f slow-update.yaml
   kubectl get pods -w
   # Po jednym Podzie naraz
   ```

3. W trakcie deploymentu Recreate sprawdź dostępność (curl Service) — będzie window 503.

## Pytania kontrolne
1. `maxSurge: 50%` + `maxUnavailable: 0` — ile Podów dodatkowo w trakcie deployu?
2. Recreate jako default — kiedy ma sens?
3. RollingUpdate + readinessProbe = wymóg — dlaczego?
