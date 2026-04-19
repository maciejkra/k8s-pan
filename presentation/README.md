# Prezentacja: Docker + Kubernetes 5-day training (2026)

Slajdy w formacie [Marp](https://marp.app/) — markdown ze sterowaniem prezentacji przez `<!-- ... -->`.

## Struktura

| Plik | Sekcje agendy | Slajdy |
|---|---|---|
| `day1.md` | 1. Wprowadzenie + K8s podstawy | ~35 |
| `day2.md` | 2. K8s workloady + AuthN/AuthZ + Sieci (intro) | ~30 |
| `day3.md` | 2. Scheduling, autoscaling, deployment + 4. NetworkPolicy | ~25 |
| `day4.md` | 3. AuthN/AuthZ (admission) + 4. Service Mesh + 9. Security | ~35 |
| `day5.md` | 5-8. Monitoring, kubeadm, Helm + 10-11. AI/GPU + Narzędzia | ~30 |

## Render

### Live preview (VS Code)
1. Zainstaluj rozszerzenie [Marp for VS Code](https://marketplace.visualstudio.com/items?itemName=marp-team.marp-vscode)
2. Otwórz dowolny `.md` z tego katalogu — preview po prawej

### Eksport HTML / PDF / PPTX

```bash
# Marp CLI
brew install marp-cli      # lub npm i -g @marp-team/marp-cli

# HTML (najlepsze do projektora przez przeglądarkę)
marp day1.md --html --output dist/day1.html

# PDF
marp day1.md --pdf --output dist/day1.pdf

# PPTX (gdy ktoś wymaga)
marp day1.md --pptx --output dist/day1.pptx

# Wszystkie dni
for d in day1 day2 day3 day4 day5; do
  marp $d.md --html --output dist/$d.html
done
```

### Tryb prezentera (speaker view)

W przeglądarce naciśnij `P` w dowolnym renderowanym HTML — otwiera się drugie okno z notatkami i podglądem następnego slajdu.

## Konwencje slajdów

- **Tytuł sekcji** = duży nagłówek + ikona dnia (D1/D2/.../D5)
- **Code blocks** = monospace, syntax highlighting przez Marp default theme
- **Cross-link** do ćwiczeń jako: `→ day1/03_dockerfile_optimization/`
- **Speaker notes** (HTML comments): `<!-- to widzi tylko prowadzący -->`

## Customize

Theme: edytuj `<!-- theme: default -->` na `gaia` lub `uncover` (built-in Marp themes), lub dodaj własny CSS w `style.css` i `<!-- theme: ./style.css -->`.

Logo Twojej firmy: dodaj `![bg right:30%](logo.png)` na pierwszym slajdzie każdego dnia.
