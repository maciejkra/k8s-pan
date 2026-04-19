#!/usr/bin/env bash
# Renders 5 day presentations to PDF and merges them into single k8s-training-2026.pdf
# Requires: npx (Marp CLI), pdfunite (poppler-utils)

set -euo pipefail
cd "$(dirname "$0")"

mkdir -p dist tmp

echo "==> 1/3 Rendering 5 day PDFs (per-day header/footer + paginacja preserved)"
for d in day1 day2 day3 day4 day5; do
  npx --yes @marp-team/marp-cli@latest "$d.md" \
    --pdf --allow-local-files \
    --output "tmp/$d.pdf" 2>&1 | tail -1
done

echo "==> 2/3 Merging into single PDF"
pdfunite tmp/day1.pdf tmp/day2.pdf tmp/day3.pdf tmp/day4.pdf tmp/day5.pdf \
  dist/k8s-training-2026.pdf

echo "==> 3/3 Cleanup"
rm -rf tmp

PAGES=$(pdfinfo dist/k8s-training-2026.pdf 2>/dev/null | grep -i pages | awk '{print $2}')
SIZE=$(du -h dist/k8s-training-2026.pdf | cut -f1)
echo ""
echo "OK: dist/k8s-training-2026.pdf ($SIZE, $PAGES stron)"
