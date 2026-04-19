# Solution — 01_nginx_image

## Lista problemów w `nginx/Dockerfile`

```dockerfile
FROM alpine                                          # 1️⃣ brak wersji
RUN apk add --update nginx                           # 2️⃣ --update zamiast --no-cache
RUN rm -rf /var/cache/apk/*                          # 3️⃣ osobny RUN = osobna warstwa (cache nie pomoże, bo poprzedni już dodał cache)
RUN mkdir -p /tmp/nginx                              # 4️⃣ kolejny zbędny RUN (3 → 1)

COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf /etc/nginx/conf.d/default.conf
WORKDIR /usr/html                                    # 5️⃣ ten katalog nie istnieje (nginx default = /usr/share/nginx/html)
ENV MY_ENV_VARIABLE="SET ON WORKSHOPS"
COPY . ./                                            # 6️⃣ kopiuje WSZYSTKO (Dockerfile, .git, .md) — cache invalidation
CMD nginx                                            # 7️⃣ shell form + brak daemon off → kontener umrze po starcie!
                                                     # 8️⃣ brak EXPOSE
                                                     # 9️⃣ brak USER (root)
                                                     # 🔟 brak HEALTHCHECK
                                                     # ⓫ brak .dockerignore
```

## Zoptymalizowany `Dockerfile.optimized`

```dockerfile
FROM nginx:1.27-alpine                               # ✅ pinowane, oficjalny obraz nginx (już ma daemon, USER, etc.)

# Konfiguracja jako pierwsza (rzadko się zmienia → cache hit)
COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf /etc/nginx/conf.d/default.conf

# Treść aplikacji jako ostatnia (zmienia się często)
COPY index.html /usr/share/nginx/html/index.html

ENV MY_ENV_VARIABLE="SET ON WORKSHOPS"

EXPOSE 80
USER nginx                                           # nieblokująca proces nie-root (oficjalny obraz ma user nginx)

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD wget -q -O /dev/null http://localhost/ || exit 1

# Oficjalny obraz nginx już ma poprawny CMD ["nginx", "-g", "daemon off;"]
# więc nie trzeba nic dodawać
```

## Plik `.dockerignore`

```
.git
.gitignore
*.md
Dockerfile*
.DS_Store
```

## Porównanie

```bash
$ docker images my-nginx
REPOSITORY   TAG          SIZE
my-nginx     latest       ~50 MB     (zły, alpine + nginx, 6 warstw zbędnych)
my-nginx     optimized    ~22 MB     (oficjalny nginx:alpine, prosty COPY)

$ docker history my-nginx
# ~10-12 warstw (każdy RUN = warstwa)

$ docker history my-nginx:optimized
# ~5-6 warstw (multi-stage NIE jest tu potrzebny — zwykła aplikacja)
```

## Odpowiedzi na pytania kontrolne

### `--no-cache` vs `--update + rm -rf`
- **Zły sposób**: `apk add --update X` zapisuje cache do `/var/cache/apk/`, **potem** osobny `RUN rm -rf` próbuje to wyczyścić. Ale każdy `RUN` to osobna warstwa! Cache jest **już** w warstwie poprzedniej, `rm` go nie usunie z obrazu — tylko nadpisze plikiem "deleted" w warstwie wyższej. **Obraz puchnie.**
- **Dobry sposób**: `apk add --no-cache X` w ogóle nie tworzy lokalnego cache. Jedna warstwa, czysto.

### `COPY . ./` na końcu
Skopiuje **wszystko** z bieżącego katalogu — łącznie z:
- `Dockerfile` (sam siebie!)
- `.git/` (cała historia repo)
- pliki `.md`, `solution.md`, dotfiles
- ewentualne secrets w `.env`

Każda zmiana w `.git/` (commit, branch) → cache miss na tej warstwie → **cały build się powtarza**. Plus secrets wyciekają do obrazu.

Mitigation: `.dockerignore` z listą tego co WYRZUCIĆ.

### `CMD nginx` vs `CMD ["nginx", "-g", "daemon off;"]`
**`CMD nginx`** (shell form) → wykonuje `/bin/sh -c "nginx"`. Nginx domyślnie **demonizuje się** (fork w tło) → proces 1 (sh) kończy się → **kontener umiera natychmiast**.

**`CMD ["nginx", "-g", "daemon off;"]`** (exec form):
- exec form (JSON array) → bezpośrednio `nginx`, bez `sh`
- `-g "daemon off;"` → wymusza foreground → kontener żyje

Test:
```bash
docker run -d --name test my-nginx       # zły Dockerfile
docker ps                                 # pusty! kontener już zmarł
docker logs test                          # nginx wystartował i zniknął
```

### `.dockerignore`
Wykonywany **przed** wysłaniem build context do Docker daemon. Bez niego cały katalog (np. `.git/` 100 MB) wędruje do daemon, wpływa na cache i powiększa context. Z `.dockerignore`: tylko potrzebne pliki idą do daemon.

```
.git
node_modules
*.log
.env
.DS_Store
```

## Cross-link

Optymalizacja Dockerfile to fundament. Następne kroki w D1:
- **`02_secure_image`** — multi-stage build dla Go binary (scratch image, ~10 MB)
- Trivy scan obrazów — *demo na żywo* (sekcja 1 agendy: "skanowanie")
- Cosign + SBOM — *prezentacja* (sekcja 9 agendy: "podpisywanie obrazów (przegląd)")
- Hardening — koncept rozszerzony w `02_secure_image` (distroless, USER nonroot, read-only FS w K8s SecurityContext D4/05)
