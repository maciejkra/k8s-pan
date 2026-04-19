# 02 — Secure image: multi-stage Go build

## Cel
Porównać dwa Dockerfile: standardowy i multi-stage. Zobaczyć redukcję rozmiaru obrazu (z ~900 MB do ~10 MB) i surface attack.

## Kontekst
Go binary można skompilować **statycznie** (bez dynamicznych dependencji) i uruchomić w `scratch` image (pusty obraz, tylko binarka + certyfikaty CA).

Plik `Dockerfile.multistage` demonstruje:
1. **Stage 1 (build)**: `golang:1.22` z pełnym toolchainem → `go build -o app`
2. **Stage 2 (runtime)**: `scratch` lub `gcr.io/distroless/static` + skopiowana binarka

Efekt: finalny obraz **10 MB** zamiast 900 MB; 0 CVE z bazowego OS (nie ma OS).

## Prereqs
- Docker / Rancher Desktop / OrbStack
- [Trivy](https://aquasecurity.github.io/trivy/) do porównania CVE

## Zadanie

1. Zbuduj obraz standardowy:
   ```bash
   docker build -t app:standard -f Dockerfile .
   docker images app:standard
   ```

2. Zbuduj obraz multistage:
   ```bash
   docker build -t app:multistage -f Dockerfile.multistage .
   docker images app:multistage
   ```

3. Porównaj rozmiary:
   ```bash
   docker images app
   ```

4. Porównaj CVE (cross-link do D1/04 Trivy):
   ```bash
   trivy image app:standard
   trivy image app:multistage
   # Multistage powinien mieć znacznie mniej CVE
   ```

5. Sprawdź warstwy:
   ```bash
   docker history app:standard
   docker history app:multistage
   ```

## Linki
- [Multi-stage builds](https://docs.docker.com/build/building/multi-stage/)
- [Distroless images](https://github.com/GoogleContainerTools/distroless)
- [Building static Go binaries](https://www.arp242.net/static-go.html)

## Cross-link
- prezentacja D1 — slajdy "Co jest źle z tym Dockerfile?", "Multi-stage build", "Trivy scan", "Supply chain — Cosign + SBOM", "Hardening obrazu — checklist"
