# Zadanie

1. Zaaplikuj `sidecar-logging.yaml` - aplikacja generuje logi do pliku, sidecar wypycha je na stdout.
2. Sprawdź logi **osobno** dla każdego z dwóch kontenerów (przydaje się flaga `-c`).
3. Zweryfikuj, że oba kontenery widzą **ten sam** wolumen `/var/log/app/`.
4. Zaaplikuj `ambassador-redis.yaml` i sprawdź, że kontenery komunikują się przez `localhost` (np. `redis-cli -h localhost ping` z drugiego kontenera).
5. Odpowiedz: jakie są 4 klasyczne wzorce multi-container pod (sidecar, ambassador, adapter, init) i kiedy stosujemy każdy z nich?
