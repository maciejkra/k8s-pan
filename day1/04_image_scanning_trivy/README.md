# 04 — Skanowanie obrazów z Trivy

## Cel
Nauczyć się skanować obrazy Docker pod kątem podatności (CVE), filtrować po severity i integrować skan z CI (exit codes).

## Kontekst
[Trivy](https://github.com/aquasecurity/trivy) to standardowy open-source scanner od Aqua Security. Skanuje:
- **OS packages** (apk, apt, yum) — podatności w bibliotekach systemowych,
- **language dependencies** (npm, pip, gomod, gem, …) — podatności w bibliotekach aplikacji,
- **misconfigurations** (Dockerfile, K8s YAML, Terraform),
- **secrets** (klucze API, prywatne klucze SSH).

Zasada: **fail fast** — skan w pipeline CI, blokujesz merge jeśli HIGH/CRITICAL CVE.

## Prereqs
- Docker
- Trivy zainstalowany lokalnie (`brew install trivy` / `apt-get install trivy` — patrz `SETUP.md`)

## Zadanie

1. Zbuduj obraz "podatny" (stary Node 14 z OpenSSL 1.x):
   ```bash
   docker build -t vuln-app:v1 vulnerable-image/
   ```
2. Pełny skan:
   ```bash
   trivy image vuln-app:v1
   ```
   Zwróć uwagę na liczbę CVE per severity (LOW / MEDIUM / HIGH / CRITICAL).

3. Skan tylko HIGH i CRITICAL:
   ```bash
   trivy image --severity HIGH,CRITICAL vuln-app:v1
   ```

4. Skan z exit code 1 dla CI (failuje pipeline jeśli znalazł HIGH/CRITICAL):
   ```bash
   trivy image --severity HIGH,CRITICAL --exit-code 1 vuln-app:v1
   echo "exit: $?"
   ```

5. Output JSON do raportu (np. dla GitHub Actions / GitLab CI):
   ```bash
   trivy image -f json -o vuln-app.json vuln-app:v1
   jq '.Results[].Vulnerabilities | length' vuln-app.json
   ```

6. Skan z `.trivyignore` — celowe ignorowanie konkretnego CVE (gdy fix nie istnieje, a ryzyko zaakceptowane):
   ```bash
   echo "CVE-2023-12345" > .trivyignore
   trivy image --ignorefile .trivyignore vuln-app:v1
   ```

7. **Bonus** — skan obrazu z poprzedniego ćwiczenia:
   ```bash
   trivy image app:bad
   trivy image app:good
   ```
   Distroless powinien mieć znacznie mniej CVE.

## Pytania kontrolne
1. Czym różni się skan OS packages od skanu language dependencies?
2. Co zrobić, gdy Trivy znalazł CVE bez patch'a? (Jakie opcje?)
3. Jak wygląda integracja z GitHub Actions? (Hint: `aquasecurity/trivy-action`)
4. Dlaczego skanujemy obrazy w D1, a Trivy Operator (skan klastra) dopiero w D4?

## Linki
- [Trivy docs](https://aquasecurity.github.io/trivy/)
- [GitHub Action](https://github.com/aquasecurity/trivy-action)
- [SARIF output dla GitHub code scanning](https://aquasecurity.github.io/trivy/latest/docs/configuration/reporting/#sarif)
