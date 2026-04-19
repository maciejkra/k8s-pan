# Zadanie

1. Stwórz Pod z aplikacji Python z obrazu `krajewskim/python-api:new`.
2. Użyj `port-forward` na port `5002` i sprawdź endpoint `/healthz`.
3. Sprawdź logi Pod-a.
4. Zrób `describe pod` i przeanalizuj sekcję `Events`.
5. Wejdź do kontenera Pod-a i wykonaj `curl localhost:5002/healthz` od środka.
