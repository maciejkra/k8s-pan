# Parallel Completion — fixed count

## Cel
Wykonać N identycznych zadań równolegle (`completions: N, parallelism: M`).

## Kontekst
Job z `completions: N` musi mieć N successful Pod-ów żeby się zakończyć. `parallelism: M` mówi ile równolegle.

Przykład:
- `completions: 10, parallelism: 3` — 10 Podów łącznie, max 3 jednocześnie. K8s uruchomi 3 → po fail/success któregoś, kolejny → … → 10 sukcesów.

Use cases: batch image processing (N obrazów do przetworzenia), test runner (N test cases równolegle), data migration podzielona na N chunks.

## Zadanie

1. Wdroż:
   ```bash
   kubectl apply -f .
   ```

2. Obserwuj:
   ```bash
   kubectl get pods -l job-name=<name> -w
   # Widzisz max parallelism Podów naraz
   ```

3. Status Job:
   ```bash
   kubectl get job
   # COMPLETIONS: 0/N → … → N/N
   ```

4. Logi wszystkich Podów Job:
   ```bash
   kubectl logs -l job-name=<name>
   ```

## Pytania kontrolne
1. Co gdy `parallelism > completions`? (Hint: K8s ograniczy do completions)
2. Co gdy Pod fail-uje? (Hint: backoffLimit + restartPolicy)
3. Indexed Job (K8s 1.24+) — co dodaje? (Hint: każdy Pod dostaje `JOB_COMPLETION_INDEX`)

## Linki
- [Job patterns](https://kubernetes.io/docs/concepts/workloads/controllers/job/#job-patterns)
