# Zadanie

Dodaj `readiness` i `liveness` probe do Pod-a python:

* `readiness` - sprawdza port TCP
* `liveness` - sprawdza endpoint `/healthz` przez HTTP

Po poprawnej konfiguracji aplikacja powinna restartować się co ~30 sekund i przez cały czas pozostawać `Ready`.

1. Zaaplikuj manifest `probes.yaml` i upewnij się, że probe są widoczne w `describe pod`.
2. Sprawdź events w `describe pod` - jakie wpisy się pojawiły?

