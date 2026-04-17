#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-localhost:5000/demo:v1}"
KEY="${KEY:-cosign.key}"

if [[ ! -f "$KEY" ]]; then
  echo "Brak $KEY — generuję parę kluczy..."
  cosign generate-key-pair
fi

echo "==> Podpisywanie $IMAGE kluczem $KEY"
cosign sign --key "$KEY" "$IMAGE"

echo "==> Generowanie SBOM"
trivy image -f cyclonedx -o sbom.json "$IMAGE"

echo "==> Dodawanie attestation SBOM"
cosign attest --key "$KEY" --predicate sbom.json --type cyclonedx "$IMAGE"

echo "OK. Weryfikacja:  ./verify.sh $IMAGE"
