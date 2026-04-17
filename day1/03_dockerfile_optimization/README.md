# 03 — Optymalizacja Dockerfile

## Cel
Porównać "naiwny" obraz z zoptymalizowanym i zrozumieć wpływ kolejności warstw, multi-stage build oraz `.dockerignore` na rozmiar i czas builda.

## Kontekst
Obraz produkcyjny powinien być:
- **mały** (mniej do pobrania, mniej powierzchni ataku),
- **szybki do zbudowania** (cache warstw — kolejność ma znaczenie),
- **bezpieczny** (mniej zależności = mniej CVE).

Trzy techniki dające największy zysk:
1. Multi-stage build — build dependencies zostają w pierwszym stage, nie trafiają do finalnego obrazu.
2. Kolejność warstw — najmniej zmieniające się instrukcje na górze (cache hit).
3. `.dockerignore` — żeby nie wysyłać do daemona całego repo (node_modules, .git, secrets).

## Prereqs
- Docker / Rancher Desktop / OrbStack
- `dive` (opcjonalnie, do analizy warstw): `brew install dive`

## Zadanie

1. Zbuduj obraz "naiwny":
   ```bash
   docker build -f Dockerfile.bad -t app:bad .
   docker images app:bad
   ```
2. Zbuduj obraz zoptymalizowany:
   ```bash
   docker build -f Dockerfile.good -t app:good .
   docker images app:good
   ```
3. Porównaj rozmiary (`docker images app`).
4. Sprawdź ile warstw zawiera każdy: `docker history app:bad` vs `docker history app:good`.
5. Zmień kod w `app/server.js` (np. dodaj `console.log`) i zbuduj oba obrazy ponownie. Który build trwa dłużej? Dlaczego?
6. Dodaj plik `.test-cache` o rozmiarze 100MB do katalogu (np. `dd if=/dev/zero of=.test-cache bs=1M count=100`). Zbuduj obraz `bad` — co się dzieje? Dodaj `.test-cache` do `.dockerignore` i zbuduj ponownie.

## Pytania kontrolne
1. Dlaczego `COPY package*.json` przed `COPY .` przyspiesza buildy?
2. Co znajduje się w finalnym obrazie multi-stage, a co tylko w stage'u build?
3. Kiedy NIE używać distroless? (Hint: debugowanie produkcji)
4. Co robi `.dockerignore` — w którym momencie buildu?

## Linki
- [Best practices for writing Dockerfiles](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Multi-stage builds](https://docs.docker.com/build/building/multi-stage/)
- [Distroless images](https://github.com/GoogleContainerTools/distroless)
