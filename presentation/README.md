# Prezentacja: Docker + Kubernetes 5-day training (2026)

Slajdy w formacie [Marp](https://marp.app/) — markdown ze sterowaniem prezentacji przez `<!-- ... -->`.

## Output

📄 **`dist/k8s-training-2026.pdf`** — jeden plik PDF (76 stron, ~1.8 MB) zawierający wszystkie 5 dni szkolenia.

## Struktura źródeł

| Plik | Slajdy | Zakres agendy |
|---|---|---|
| `day1.md` | 14 | Docker hardening + K8s podstawy |
| `day2.md` | 14 | Workloady, AuthN/AuthZ, Gateway API |
| `day3.md` | 14 | Scheduling, autoscaling, deployment strategies |
| `day4.md` | 16 | Security pełen stack |
| `day5.md` | 18 | Helm, monitoring, kubeadm, AI/GPU |

Każdy plik ma **swój własny header/footer** i **paginację 1-N** zachowane w finalnym PDF — naturalna nawigacja "Day 3, slajd 7" dla prowadzącego.

## Build

### Wymagania
- `npx` (Node.js)
- `pdfunite` (poppler-utils): `brew install poppler` na macOS

### Wygeneruj jeden plik PDF

```bash
./build.sh
# OK: dist/k8s-training-2026.pdf (1,8M, 76 stron)
```

Skrypt:
1. Renderuje 5 tymczasowych PDF (per dzień) przez Marp CLI
2. Scala je w `dist/k8s-training-2026.pdf` przez `pdfunite`
3. Czyści katalog `tmp/`

### Live preview (podczas edycji)

VS Code: zainstaluj [Marp for VS Code](https://marketplace.visualstudio.com/items?itemName=marp-team.marp-vscode), otwórz dowolny `dayN.md` — preview po prawej z hot reload.

### Inne formaty (opcjonalnie)

```bash
# HTML jednego dnia (np. do projektora przez przeglądarkę)
npx --yes @marp-team/marp-cli@latest day1.md --html --output dist/day1.html

# PPTX
npx --yes @marp-team/marp-cli@latest day1.md --pptx --output dist/day1.pptx
```

### Tryb prezentera (speaker view)

W przeglądarce z renderowanym HTML naciśnij `P` — otwiera się drugie okno z notatkami i podglądem następnego slajdu.

## Konwencje

- **Tytuł sekcji** = duży nagłówek + ikona dnia (D1/D2/.../D5)
- **Code blocks** = monospace, syntax highlighting (Marp default theme)
- **Cross-link** do ćwiczeń jako: `→ day1/02_secure_image/`
- **Speaker notes** (HTML comments): `<!-- to widzi tylko prowadzący -->`
- **Style**: każdy `dayN.md` ma w frontmatter `style:` z custom CSS — zmniejszony font + spacing tak żeby wszystkie slajdy mieściły się na jednej stronie

## Customize

**Theme**: edytuj `theme: default` w frontmatter każdego `dayN.md` na `gaia` lub `uncover` (built-in Marp themes), lub dodaj własny CSS w `style.css` i `theme: ./style.css`.

**Logo firmy**: dodaj `![bg right:30%](logo.png)` na pierwszym slajdzie każdego dnia.

**Header/Footer**: edytuj `header:` i `footer:` w frontmatter `dayN.md`.
