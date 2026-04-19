# Zadanie

Do **deploymentu Python** (z `D1/10` Python+Redis) dodaj **ConfigMap** z konfiguracją aplikacji.

1. Stwórz ConfigMap zawierający `LOG_LEVEL=DEBUG` i `REDIS_HOST=<nazwa-twojego-redis-service>`.
2. Zmień **Python Deployment** tak, aby brał env z ConfigMap (przez `envFrom: configMapRef`) — usuń hardcoded env-y z manifestu.
3. Wykonaj rolling update Deploymentu i sprawdź, że Pody nadal poprawnie łączą się z Redis (`kubectl logs deploy/python` → szukaj DEBUG-ów).
4. Edytuj ConfigMap (`kubectl edit configmap python-config`) zmieniając `LOG_LEVEL` na `INFO`.

**Pytanie:** czy zmiana env-a z ConfigMap propaguje się do Pod-ów *bez* restartu? Jak to wymusić? (znasz `Reloader`?)

## Bonus — ConfigMap jako volume

Stwórz drugi ConfigMap z plikiem konfiguracyjnym (np. `service.config`) i zamontuj go jako wolumen do `/etc/config/`. Wyedytuj plik — sprawdź, czy aktualizuje się on w mountcie po ~60 sekundach **bez** restartu Pod-a.

Pliki referencyjne w katalogu (przykłady do podejrzenia):
- `pod-config.yaml` — env vars z ConfigMap
- `pod-config-volume.yaml` — ConfigMap jako mounted file
- `creation/` — różne sposoby tworzenia ConfigMap (z pliku, z literałów, z env-file)
