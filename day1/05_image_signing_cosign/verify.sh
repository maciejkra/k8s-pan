#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-localhost:5000/demo:v1}"
PUB="${PUB:-cosign.pub}"

echo "==> Weryfikacja podpisu"
cosign verify --key "$PUB" "$IMAGE"

echo "==> Weryfikacja attestation SBOM"
cosign verify-attestation --key "$PUB" --type cyclonedx "$IMAGE"
