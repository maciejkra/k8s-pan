# 05 — Podpisywanie obrazów z Cosign + SBOM

## Cel
Podpisać obraz Docker (keyless signing przez OIDC) i wygenerować SBOM (Software Bill of Materials). Zweryfikować podpis.

## Kontekst
Supply chain attacks (SolarWinds, codecov, log4j) pokazały: trzeba wiedzieć **kto** zbudował obraz, **z czego** i **czy nikt go nie podmienił** w drodze do registry → klastra.

[Cosign](https://github.com/sigstore/cosign) (część projektu Sigstore) rozwiązuje to przez:
- **podpisy kryptograficzne** obrazów,
- **keyless signing** — podpisuje krótko żyjącym certem od OIDC providera (GitHub Actions, Google, …), bez konieczności trzymania kluczy,
- **transparency log** (Rekor) — wszystkie podpisy logowane publicznie (jak Certificate Transparency dla TLS).

SBOM = lista wszystkich komponentów obrazu (OS packages + libraries + wersje + licencje). Format: SPDX lub CycloneDX.

## Prereqs
- Docker
- Cosign (`brew install cosign`)
- Lokalny rejestr (możemy użyć K3d's registry albo `docker run -d -p 5000:5000 registry:2`)

## Zadanie

### Wariant A — keyless signing (rekomendowane do CI)

1. Uruchom lokalny registry:
   ```bash
   docker run -d -p 5000:5000 --name registry registry:2
   ```
2. Zbuduj i pushuj obraz:
   ```bash
   docker build -t localhost:5000/demo:v1 -f Dockerfile .
   docker push localhost:5000/demo:v1
   ```
3. Podpisz keyless (otwiera browser dla OIDC challenge):
   ```bash
   COSIGN_EXPERIMENTAL=1 cosign sign localhost:5000/demo:v1
   ```
4. Zweryfikuj:
   ```bash
   COSIGN_EXPERIMENTAL=1 cosign verify localhost:5000/demo:v1 \
     --certificate-identity-regexp ".*" \
     --certificate-oidc-issuer-regexp ".*"
   ```

### Wariant B — z kluczem (do offline / on-prem)

1. Wygeneruj parę kluczy:
   ```bash
   cosign generate-key-pair          # tworzy cosign.key + cosign.pub
   ```
2. Podpisz:
   ```bash
   cosign sign --key cosign.key localhost:5000/demo:v1
   ```
3. Zweryfikuj:
   ```bash
   cosign verify --key cosign.pub localhost:5000/demo:v1
   ```

### SBOM (z Trivy)

1. Wygeneruj SBOM (CycloneDX):
   ```bash
   trivy image -f cyclonedx -o sbom.json localhost:5000/demo:v1
   ```
2. Dołącz SBOM jako attestation do obrazu:
   ```bash
   cosign attest --key cosign.key --predicate sbom.json \
     --type cyclonedx localhost:5000/demo:v1
   ```
3. Zweryfikuj attestation:
   ```bash
   cosign verify-attestation --key cosign.pub \
     --type cyclonedx localhost:5000/demo:v1
   ```

## Pytania kontrolne
1. Co lepsze dla CI: keyless czy z kluczem? Dlaczego?
2. Co to jest Rekor i czemu jest publiczny?
3. SBOM w formacie SPDX vs CycloneDX — kiedy które?
4. Jak wymusić w klastrze K8s, żeby uruchamiały się tylko podpisane obrazy? (Hint: Cosign + OPA/Gatekeeper lub Sigstore Policy Controller — patrz D4)

## Linki
- [Sigstore](https://www.sigstore.dev/)
- [Cosign docs](https://docs.sigstore.dev/cosign/overview/)
- [SLSA framework](https://slsa.dev/) — poziomy supply chain integrity
