# Prezentacja: Docker + Kubernetes 5-day training (2026)

Prezentacja w stylu **jsystems** — KubeCon design, generowana z HTML przez `html2pptx`.

## Output

📄 **`pptx/dist/k8s-training-2026.pptx`** — jeden PPTX (65 slajdów, 5 dni). Edytowalny w PowerPoint / Keynote / LibreOffice.

## Struktura

```
pptx/
├── build.js                  # Node.js script — html2pptx workflow
├── html/                     # 65 plików HTML, jeden per slajd
│   ├── d1-01-cover.html      ← 16 slajdów Day 1
│   ├── d2-01-cover.html      ← 12 slajdów Day 2
│   ├── d3-01-cover.html      ← 10 slajdów Day 3
│   ├── d4-01-cover.html      ← 13 slajdów Day 4
│   ├── d5-01-cover.html      ← 14 slajdów Day 5
│   └── *.png                 # logo Docker, K8s, Helm, Cosign
└── dist/
    ├── k8s-training-2026.pptx
    └── preview-*.jpg          # thumbnails do quick review
```

## Build

### Wymagania
- Node.js + npm
- Globalne pakiety: `pptxgenjs`, `playwright`, `sharp`

### Wygeneruj PPTX

```bash
cd pptx
NODE_PATH=$(npm root -g) node build.js
```

### Generowanie thumbnails

```bash
SKILL_DIR=/Users/jamicque/.claude/plugins/cache/anthropic-agent-skills/document-skills/69c0b1a06741/skills/pptx
python3 $SKILL_DIR/scripts/thumbnail.py dist/k8s-training-2026.pptx dist/preview --cols 5
```

### Eksport PDF

```bash
soffice --headless --convert-to pdf dist/k8s-training-2026.pptx --outdir dist/
```

## Style — KubeCon / jsystems

- **Cover (D1-D5)**: ciemne tło `#0F172A` + JSYSTEMS branding + niebieska linia akcent `#326CE5` + duży tytuł + prawy panel `#1E293B` z logiem (Docker, K8s, Helm, Cosign)
- **Content**: jasne tło `#FAFAFA` + nagłówek z niebieską linią pod
- **Comparison**: czerwony `#DC2626` vs zielony `#059669` headers (np. bad/good Dockerfile)
- **Section divider**: jasne tło + duży emoji + gigantyczny tytuł
- **Code**: ciemne `#1E1E2E` + Catppuccin colors
- **Tables**: nagłówek `#1E293B` biały, niebieska kolumna typu `#326CE5`
- **Notes**: niebieskie (info), żółte (warning), czerwone (danger)
- **Font**: Arial (web-safe, podobna do Inter z jsystems)

## Edycja

```bash
# Edytuj treść slajdu
code html/d1-04-bad-dockerfile.html

# Re-build
NODE_PATH=$(npm root -g) node build.js

# Otwórz PPTX
open dist/k8s-training-2026.pptx
```

## Restrykcje html2pptx

❌ Nie wspiera: `<table>` (użyj `<div class="row">` z flex), CSS gradients (rasteryzuj przez Sharp), `margin` na `<span>`, bullet chars w `<p>` (użyj `<ul>` lub `&nbsp;`)

✅ Wspiera: `<p>`, `<h*>`, `<ul>`, `<ol>`, `<b>/<i>/<u>`, `<span>` z color/bold, `<div>` z bg/border/shadow, `<img>`, Flexbox

## Statystyki

- **65 slajdów** (D1: 16, D2: 12, D3: 10, D4: 13, D5: 14)
- **~3 MB PPTX** + thumbnails ~600 KB
- Build time **~1 min**
