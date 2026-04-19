# Zadanie

1. Zbuduj dwa obrazy: `app:standard` z `Dockerfile` oraz `app:multistage` z `Dockerfile.multistage`.
2. Porównaj ich rozmiary - o ile mniejszy jest multistage?
3. Przeskanuj oba obrazy Trivy i porównaj liczbę CVE (skup się na poziomie HIGH/CRITICAL).
4. Sprawdź warstwy w obu obrazach. Co znika w wersji multistage?
5. Odpowiedz: dlaczego obraz typu `scratch` / `distroless` ma 0 CVE z systemu?
