#!/usr/bin/env bash
# Pełny przykład CI-friendly skanowania
set -e

IMAGE="${1:-vuln-app:v1}"
SEVERITY="${SEVERITY:-HIGH,CRITICAL}"

echo "==> Skan: $IMAGE (severity: $SEVERITY)"
trivy image --severity "$SEVERITY" --exit-code 1 --no-progress "$IMAGE"

echo "==> Generowanie raportu SARIF (GitHub code scanning)"
trivy image --severity "$SEVERITY" -f sarif -o "trivy-${IMAGE//[:\/]/_}.sarif" "$IMAGE"

echo "==> Generowanie SBOM (CycloneDX)"
trivy image -f cyclonedx -o "sbom-${IMAGE//[:\/]/_}.json" "$IMAGE"

echo "Skan OK. Raporty: trivy-*.sarif, sbom-*.json"
