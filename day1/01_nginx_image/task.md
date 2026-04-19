# Zadanie

1. Zbuduj obraz z `nginx/Dockerfile`, uruchom kontener i sprawdź, czy odpowiada na `localhost:8080`.
2. Sprawdź liczbę warstw oraz rozmiar obrazu.
3. Otwórz `Dockerfile` i wypisz wszystkie problemy, jakie zauważasz (cel: 8-10).
4. Stwórz `nginx/Dockerfile.optimized`, w którym poprawisz znalezione błędy (rozmiar, warstwy, cache, `USER`, `EXPOSE`, `HEALTHCHECK`, `CMD` w trybie exec, `.dockerignore`, ...).
5. Porównaj rozmiar i liczbę warstw przed i po optymalizacji. O ile spadło?
6. Przedyskutuj z prowadzącym: kiedy pinować wersje obrazu bazowego, a kiedy używać tagu zmiennego?
