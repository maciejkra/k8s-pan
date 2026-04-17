# Solution — 05_image_signing_cosign

## Wyjaśnienia

### Keyless vs z kluczem
- **Keyless**: nie ma długo żyjącego klucza do skradzenia. Tożsamość pochodzi z OIDC (np. GitHub Actions identity). Idealne dla CI: każdy build jest podpisany przez `repo:owner/repo:ref:refs/heads/main` zamiast anonimowy klucz.
- **Z kluczem**: wymagane na on-prem bez dostępu do internetu (Sigstore public good infrastructure jest publiczne). Klucz prywatny trzeba chronić (HSM, Vault, KMS).

### Rekor (transparency log)
Append-only log wszystkich podpisów. Publiczny — każdy może sprawdzić, że konkretny obraz został podpisany przez konkretną tożsamość. Analogia: Certificate Transparency dla TLS — wykrywa rogue certyfikaty wystawione bez wiedzy właściciela domeny.

### SPDX vs CycloneDX
- **SPDX**: starszy, bardziej szczegółowy, ISO standard. Preferowany do compliance (licensing audits).
- **CycloneDX**: nowszy, lżejszy, security-focused. Preferowany do supply chain/vuln management.

W praktyce: oba formaty są wymienne, większość narzędzi rozumie oba (Trivy generuje oba przez `-f spdx` lub `-f cyclonedx`).

### Wymuszenie podpisanych obrazów w K8s
Trzy podejścia:
1. **Sigstore Policy Controller** (admission controller) — `kubectl apply` Pod z niepodpisanym obrazem → odrzucony.
2. **OPA/Gatekeeper** — ConstraintTemplate z external data provider sprawdzającym Cosign signature (patrz D4/09).
3. **Connaisseur** (alternatywa) — admission webhook dedykowany weryfikacji podpisów.

Demo D4 (`12_supply_chain.md`) pokazuje pełny flow: build → sign → push → admission verify → schedule.

## Walidacja

```bash
# Keyless lokalny test (działa offline z lokalnym registry, ale OIDC wymaga internetu):
COSIGN_EXPERIMENTAL=1 cosign sign --rekor-url http://localhost:5050 ...
# (alternatywnie: lokalny Rekor server)
```

W klasycznym setupie szkolenia używamy **wariantu B (z kluczem)** — działa offline i nie wymaga konfiguracji OIDC providera.
