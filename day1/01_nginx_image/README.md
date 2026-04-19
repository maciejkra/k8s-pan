# 01 — Pierwszy Docker image: nginx

## Cel
Zbudować własny obraz Docker nginx z custom config, uruchomić, sprawdzić jak warstwy Dockerfile wpływają na rozmiar i cache.

## Kontekst
To najprostszy "hello world" Dockera: FROM istniejący nginx, skopiuj własny config i index.html. Dobra baza do dyskusji:
- Kolejność warstw (cache hit/miss)
- Co kopiować a co nie (`.dockerignore`)
- Kiedy pinować wersje (`nginx:1.27-alpine` vs `nginx:latest`)

Pełne ćwiczenie optymalizacji: **D1/03 dockerfile_optimization**.

## Prereqs
- Docker / Rancher Desktop / OrbStack

## Zadanie

1. Zbuduj obraz z katalogu `nginx/` (Dockerfile jest tam):
   ```bash
   docker image build -t my-nginx -f nginx/Dockerfile nginx/
   ```

2. Uruchom kontener:
   ```bash
   docker run -d --rm -p 8080:80 --name my-nginx my-nginx
   curl http://localhost:8080
   ```

3. Sprawdź warstwy:
   ```bash
   docker history my-nginx
   docker image ls | head
   ```

4. **Pytanie do dyskusji**: Co można zoptymalizować w tym Dockerfile?
   - Kolejność instrukcji (cache)
   - Base image (alpine vs slim vs full)
   - Multi-stage (tutaj nie potrzebne — sam nginx)
   - `.dockerignore`

## Pytania kontrolne
1. Czemu `docker run --rm`? Co bez tego?
2. `-p 8080:80` — co oznacza?
3. `nginx:1.27-alpine` vs `nginx:latest` — który do produkcji i dlaczego?
4. Gdzie nginx szuka config plików? (Hint: `/etc/nginx/nginx.conf`, `/etc/nginx/conf.d/*.conf`)

## Linki
- [Dockerfile reference](https://docs.docker.com/engine/reference/builder/)
- [Best practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- Pełne ćwiczenie optymalizacji: [`../03_dockerfile_optimization/`](../03_dockerfile_optimization/)
