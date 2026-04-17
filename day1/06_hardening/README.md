# 06 — Hardening obrazów Docker

## Cel
Zastosować checklist hardeningu do obrazu produkcyjnego: distroless, non-root, read-only FS, minimalne capabilities, healthcheck w obrazie, lint Dockerfile.

## Kontekst
Hardening obrazu = redukcja powierzchni ataku **w samym obrazie**, niezależnie od polityk K8s. Zasada: obraz powinien być bezpieczny **nawet jeśli** ktoś go uruchomi bez SecurityContext / PSA.

Hardening obrazu uzupełnia hardening klastra (D4: SecurityContext, PSA, NetworkPolicy).

## Prereqs
- Docker
- Hadolint (`brew install hadolint`)

## Zadanie

1. **Lint Dockerfile** — sprawdź jakość bazowego Dockerfile:
   ```bash
   hadolint Dockerfile.weak
   ```
   Zwróć uwagę na ostrzeżenia (DL3008, DL3015, DL3018 …).

2. **Zbuduj wzmocniony obraz**:
   ```bash
   docker build -f Dockerfile.hardened -t app:hardened .
   ```

3. **Uruchom z minimalnym SecurityContext** (symulacja produkcji):
   ```bash
   docker run --rm -d --name app-hardened \
     --read-only \
     --tmpfs /tmp \
     --cap-drop ALL \
     --security-opt no-new-privileges \
     -p 8080:8080 \
     app:hardened
   curl http://localhost:8080/health
   ```

4. Spróbuj zapisać do FS w działającym kontenerze:
   ```bash
   docker exec app-hardened touch /test 2>&1 || echo "OK — readonly działa"
   docker exec app-hardened touch /tmp/test && echo "OK — tmpfs działa"
   ```

5. **Healthcheck** zdefiniowany w obrazie:
   ```bash
   docker inspect --format='{{json .State.Health}}' app-hardened | jq
   ```

6. Porównaj z `Dockerfile.weak`:
   ```bash
   docker build -f Dockerfile.weak -t app:weak .
   docker images app
   ```

## Checklist hardeningu (do dyskusji)

- [ ] Distroless lub minimal base (alpine, scratch)
- [ ] Non-root USER
- [ ] Pinowane wersje (`nginx:1.27.0-alpine` zamiast `nginx:latest`)
- [ ] Multi-stage build (build deps wyrzucone)
- [ ] `.dockerignore` (brak `.git`, secrets)
- [ ] HEALTHCHECK
- [ ] EXPOSE tylko porty rzeczywiście używane
- [ ] Brak `apt-get upgrade` (powoduje niedeterministyczne buildy)
- [ ] Brak `curl | bash` w buildzie (audytowalność)
- [ ] `--no-cache-dir` przy `pip install`, `--no-install-recommends` przy apt
- [ ] Hadolint w CI
- [ ] Trivy scan w CI z exit-code (D1/04)
- [ ] Cosign signature w CI (D1/05)

## Pytania kontrolne
1. Dlaczego `USER nonroot` w obrazie + `runAsNonRoot: true` w PSA — to redundancja czy obrona w głębi?
2. Co jeśli aplikacja musi pisać do FS? (Hint: emptyDir + tmpfs / writable volume)
3. Kiedy `scratch` zamiast `distroless`? (Hint: Go static binary)
4. Co Hadolint nie wykryje a Trivy tak? (i odwrotnie?)

## Linki
- [Docker security best practices](https://docs.docker.com/develop/security-best-practices/)
- [OWASP Docker top 10](https://github.com/OWASP/Docker-Security)
- [Hadolint rules](https://github.com/hadolint/hadolint/wiki)
