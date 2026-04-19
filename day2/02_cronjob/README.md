# 02 — CronJob

## Cel
Zaplanować zadania cykliczne w klastrze przez CronJob. Zrozumieć różnicę między Job (jednorazowy) i CronJob (powtarzalny).

## Kontekst
**CronJob** = kontroler tworzący Job-y wg harmonogramu cron (`*/5 * * * *`). Każde uruchomienie tworzy nowy Job → nowy Pod.

Use cases:
- Backup baz danych
- Czyszczenie starych danych (retention policies)
- Generowanie raportów
- Pollowanie zewnętrznych API

**Pułapki**:
- `concurrencyPolicy: Allow|Forbid|Replace` — co gdy poprzednia instancja jeszcze działa
- `startingDeadlineSeconds` — co gdy controller-manager był down podczas planowanego uruchomienia
- CronJob **łatwo zalewa node** gdy Joby się piętrzą (Pending → kumulują się)

## Prereqs
- K3d/Kind cluster
- Pomocny: [crontab.guru](https://crontab.guru) do walidacji wyrażeń cron

## Zadanie

1. Zaaplikuj CronJob (uruchamia się co minutę):
   ```bash
   kubectl apply -f cronjob.hello.yaml
   kubectl get cronjob
   ```

2. Po ~2 minutach sprawdź utworzone Joby i Pody:
   ```bash
   kubectl get job -l origin=cron
   kubectl get pod -l origin=cron-job
   kubectl logs -l origin=cron-job
   ```

3. Sprzątnij i sprawdź że Joby/Pody pozostają (CronJob nie sprząta automatycznie domyślnie):
   ```bash
   kubectl delete -f cronjob.hello.yaml
   kubectl get job -l origin=cron      # nadal są (jeśli successfulJobsHistoryLimit > 0)
   kubectl get pod -l origin=cron-job
   ```


## Linki
- [CronJob docs](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/)
- [crontab.guru](https://crontab.guru) — walidator wyrażeń cron
