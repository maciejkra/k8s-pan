# 03 — Pod z multi-GPU

## Cel
Wdrożyć Pod używający 4 GPU jednocześnie (cały node) — typowy single-node training job.

## Zadanie

1. Wdroż:
   ```bash
   kubectl apply -f pod.yaml
   ```

2. Sprawdź:
   ```bash
   kubectl describe pod multi-gpu-job | grep -A 5 "Limits:"
   # Limits:
   #   nvidia.com/gpu:  4
   ```

3. Spróbuj wdrożyć drugi 4-GPU Pod:
   ```bash
   kubectl apply -f pod-second.yaml
   kubectl get pods
   # Drugi Pod może być Pending lub przejdzie na drugi node
   ```

4. Sprzątnij:
   ```bash
   kubectl delete pod multi-gpu-job multi-gpu-job-2
   ```

## Pytania kontrolne
1. Czy `nvidia.com/gpu: 4` zawsze dostaje 4 fizyczne GPU? (Hint: time-slicing, MIG)
2. Jak wyspecyfikować, że potrzebujesz 4 GPU **na jednym node** (vs 4 GPU na różnych nodach)?
3. Co to "exclusive vs shared" GPU access?
