# Solution — 04_image_scanning_trivy

## Spodziewane wyniki

`vuln-app:v1` (Node 14 + Buster + stare deps) — typowo:
- **CRITICAL**: 50-150 CVE
- **HIGH**: 200-400 CVE
- **MEDIUM**: 500+

`app:good` (distroless + Node 20) — typowo:
- **CRITICAL**: 0-2 CVE
- **HIGH**: 0-5

## Odpowiedzi na pytania

### OS vs language dependencies
- **OS**: skanuje pakiety zainstalowane przez `apt`/`apk`/`yum` w bazowym obrazie (np. `openssl`, `libxml2`).
- **Language**: parsuje `package-lock.json`/`requirements.txt`/`go.sum` i sprawdza biblioteki zainstalowane przez npm/pip/go mod.

Distroless eliminuje większość OS CVE — nie ma `apt`, nie ma `bash`, nie ma `coreutils`.

### CVE bez patcha
Opcje:
1. Czekać na fix od upstream (śledzić `nvd.nist.gov` / `github advisories`).
2. Akceptować ryzyko i dodać do `.trivyignore` z komentarzem (kiedy review, czemu OK).
3. Zmienić bazę obrazu (np. z Debian na Alpine — różne wersje pakietów).
4. Self-patch — zbudować patched binarkę samodzielnie (rzadkie).
5. Mitygacja na poziomie K8s (NetworkPolicy, RBAC) — utrudnia eksploitację, nie usuwa CVE.

### GitHub Actions integration
```yaml
- name: Run Trivy
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ghcr.io/${{ github.repository }}:${{ github.sha }}
    format: sarif
    output: trivy-results.sarif
    severity: HIGH,CRITICAL
    exit-code: '1'
- uses: github/codeql-action/upload-sarif@v3
  if: always()
  with:
    sarif_file: trivy-results.sarif
```

### D1 vs D4
- **D1 (`trivy image`)**: skan **statyczny** — przed deployem, jako gate w CI.
- **D4 (Trivy Operator)**: skan **w klastrze** — ciągły, pokazuje co aktualnie działa, raportuje CVE które pojawiły się PO deployu (np. nowy CVE w bibliotece, którą używa już zdeployowana aplikacja).

Oba potrzebne — różne fazy lifecycle.
