# 01 — Pierwszy Docker image: nginx + dyskusja "co jest źle?"

## Cel
Zbudować obraz nginx z istniejącego (celowo **nieoptymalnego**) Dockerfile, uruchomić, **znaleźć wszystkie problemy** i dyskutować jak go zoptymalizować.

To wprowadzenie do **optymalizacji Dockerfile** (sekcja 1 agendy) — przez krytykę realnego przykładu, nie suchą teorię.

## Kontekst
Dostajesz Dockerfile który **działa**, ale ma 8-10 problemów typowych dla początkujących:
- Cache miss przy każdym buildzie
- Niepotrzebnie duże warstwy
- Brak pinowanych wersji
- Złe użycie CMD (kontener może umrzeć!)
- Brak USER, EXPOSE, healthcheck

Twoim zadaniem jest **znaleźć problemy** i zoptymalizować.

## Prereqs
- Docker / Rancher Desktop / OrbStack

## Zadanie

### Część 1 — zbuduj i uruchom

```bash
cd nginx/
docker image build -t my-nginx -f Dockerfile .
docker images my-nginx
docker run -d --rm -p 8080:80 --name my-nginx my-nginx
curl http://localhost:8080
```

Sprawdź ile warstw:
```bash
docker history my-nginx
```

### Część 2 — znajdź problemy

Otwórz `nginx/Dockerfile` i odpowiedz: **ile problemów potrafisz wymienić?** Spróbuj sam zanim spojrzysz na `solution.md`.

Hint — patrz na:
- 🔴 Tag bazowego image
- 🔴 Liczba warstw (`RUN`)
- 🔴 `apk add` flagi
- 🔴 Kolejność `COPY` (cache!)
- 🔴 `WORKDIR` — czy istnieje w nginx default?
- 🔴 `COPY . ./` — co tu zostanie skopiowane?
- 🔴 `CMD nginx` — co się stanie z procesem?
- 🔴 Brak `USER`, `EXPOSE`, `HEALTHCHECK`
- 🔴 Brak `.dockerignore`

### Część 3 — zoptymalizuj

Stwórz `Dockerfile.optimized` w katalogu `nginx/` rozwiązujący wszystkie problemy. Zbuduj:

```bash
docker image build -t my-nginx:optimized -f Dockerfile.optimized .
docker images my-nginx
```

Porównaj:
- Rozmiar (powinien spaść)
- Liczba warstw (`docker history`)
- Czas drugiego buildu (cache!)

### Część 4 — dyskusja (z prowadzącym)

- Co zmieniłbyś jeszcze?
- Kiedy pinować na konkretną wersję, kiedy `:latest`?
- Co byłoby gdyby `nginx` byłby aplikacją która **musi** zapisywać do `/var/log`?
- Jak doliczyć `HEALTHCHECK` żeby Docker wiedział że nginx odpowiada?

## Pytania kontrolne
1. Dlaczego `apk add --no-cache` jest lepsze niż `apk add --update` + `rm -rf /var/cache/apk/*`?
2. `COPY . ./` na końcu — co konkretnie skopiuje? Co z plikami `.git/`, `*.md`?
3. `CMD nginx` vs `CMD ["nginx", "-g", "daemon off;"]` — która forma jest poprawna i dlaczego?
4. Po co `.dockerignore`? W którym momencie buildu jest używany?

## Linki
- [Dockerfile reference](https://docs.docker.com/engine/reference/builder/)
- [Best practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [`solution.md`](./solution.md) — pełna lista problemów + zoptymalizowany Dockerfile
