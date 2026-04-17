# Solution — 06_hardening

## Spodziewane wyniki Hadolint dla Dockerfile.weak

```
DL3007 Using latest is prone to errors if the image will ever update.
DL3008 Pin versions in apt-get install (e.g. apt-get install <package>=<version>)
DL3015 Avoid additional packages by specifying --no-install-recommends
DL3013 Pin versions in pip install
DL3025 Use arguments JSON notation for CMD and ENTRYPOINT
DL3002 Last USER should not be root
ADD instead of COPY (DL3020)
```

## Porównanie rozmiarów

| Obraz | Rozmiar | USER | FS |
|---|---|---|---|
| `app:weak` | ~600 MB | root | rw |
| `app:hardened` | ~80 MB | nonroot (uid 65532) | wymagany --read-only |

## Odpowiedzi

### USER nonroot vs runAsNonRoot — obrona w głębi
Tak, redundancja, ale celowa:
- Image-level USER chroni gdy ktoś uruchomi obraz **bez** PSA (lokalnie, w starym klastrze, w docker compose).
- PSA `runAsNonRoot: true` jest wymuszeniem na poziomie klastra, nie ufa obrazowi.

Dwa zamki na drzwiach.

### Aplikacja musi pisać do FS
- **Cache/temp**: `volumeMounts: emptyDir.medium: Memory` (tmpfs w K8s)
- **Persistent state**: PVC z dedykowanym mount path; reszta FS pozostaje read-only
- **Logi**: STDOUT/STDERR (12-factor), nie pliki

### scratch vs distroless
- **scratch**: tylko binary + biblioteki staticznie linkowane. Działa dla Go (`CGO_ENABLED=0`), Rust (`musl`). Najmniejszy obraz (~5 MB).
- **distroless**: ma libc, libssl, certyfikaty CA, system trust store. Wymagane dla Java, Python, Node.js (potrzebują dynamic libs).

### Hadolint vs Trivy
- **Hadolint**: lint statyczny **Dockerfile** — best practices, antywzorce składniowe. Nie wie nic o CVE.
- **Trivy**: lint **zbudowanego obrazu** — CVE w pakietach. Nie wie nic o złych praktykach Dockerfile (poza `image` config).

Komplementarne, oba w CI.
