# Zadanie

Napisz **CronJob**, który **zwiększy licznik aplikacji Python** (z deploymentu Python+Redis z `D1/10`) **co minutę**.

Użyj obrazu `cmd.cat/curl` do tego zadania.

**Pytanie:** pod jaki adres CronJob powinien wysyłać request `curl`?

## Hint

- Endpoint do increment: `POST /api/v1/info`
- Aplikacja Python jest dostępna przez Service utworzony w `D1/10`
- Wewnątrz klastra Service rozwiązuje się przez DNS — w jakim formacie?
- CronJob, Service i Deployment muszą być w tym samym namespace (lub trzeba podać FQDN)

## Bonus

1. Sprawdź wartość licznika przed i po — `GET /api/v1/info` z zewnątrz klastra (port-forward / NodePort).
2. Rozszerz manifest o `successfulJobsHistoryLimit: 3` i `concurrencyPolicy: Forbid`. Co dają te ustawienia?
3. Zmień harmonogram na co 5 minut (sprawdź wyrażenie na crontab.guru).
