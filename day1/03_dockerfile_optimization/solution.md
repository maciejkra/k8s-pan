# Solution — 03_dockerfile_optimization

## Oczekiwane wyniki

| Obraz | Rozmiar (przybliżony) | Liczba warstw |
|---|---|---|
| `app:bad` (node:20 + apt + global tsc) | ~1.2 GB | ~9 |
| `app:good` (multi-stage + distroless) | ~150 MB | ~6 |

## Wyjaśnienia

### Dlaczego `COPY package*.json` przed `COPY .`
Docker cache'uje warstwy. Jeśli `package.json` się nie zmienił, `npm ci` nie musi się ponownie wykonywać. Gdyby `COPY .` był pierwszy — każda zmiana w kodzie aplikacji invalidowałaby `npm ci` (najdłuższy krok).

### Co jest w distroless
Tylko runtime (Node.js, jego zależności systemowe, certyfikaty CA). Brak: shell, package manager, `curl`, `wget`, `vim`. Mniej narzędzi → trudniej eskalować jeśli ktoś włamie się do kontenera.

### Kiedy NIE distroless
- Debugowanie produkcyjnego incydentu — nie ma `kubectl exec sh`. Workaround: `kubectl debug` z ephemeral container (image z busyboxem podpinany do tego samego namespace pidów).
- Aplikacje wymagające nietypowych binarek systemowych (rzadkie).

### `.dockerignore`
Wykonywany **przed** wysłaniem build context do daemona Dockera. Bez niego cały katalog (np. `.git/`, `node_modules/`, `.test-cache`) wędruje do daemon i wpływa na cache (zmiana .git invalidates cache).

## Walidacja kroku 6
```bash
dd if=/dev/zero of=.test-cache bs=1M count=100
time docker build -f Dockerfile.bad -t app:bad .
# Sending build context: ~100MB+

# Po dodaniu .test-cache do .dockerignore:
time docker build -f Dockerfile.bad -t app:bad .
# Sending build context: <1MB
```
