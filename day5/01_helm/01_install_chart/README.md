# 01 — Helm: instalacja chartu z repo

## Cel
Zainstalować Helm chart z repozytorium autora. Poznać `helm install`, `helm upgrade`, `helm rollback` — pełny lifecycle release.

## Kontekst
**Helm** = menedżer paczek K8s. Chart = paczka zawierająca template-owane manifesty + values. Release = instancja chartu zainstalowana w klastrze.

Kluczowe komendy:
- `helm install` — nowy release
- `helm upgrade` — aktualizacja istniejącego (z fallback gdy nie istnieje: `--install`)
- `helm rollback` — cofnięcie do poprzedniej rewizji
- `helm uninstall` — usunięcie release
- `helm pull --untar` — pobranie chartu lokalnie (do studiowania / forkowania)

**`--atomic`** (rekomendowane produkcyjnie) = przy niepowodzeniu automatyczne rollback. Bez tej flagi częściowo zaaplikowane manifesty zostają w klastrze i utrudniają debug.

## Prereqs
- K3d/Kind cluster
- [helm](https://helm.sh/docs/intro/install/) zainstalowany
- Opcjonalnie: [helm completion](https://v3-1-0.helm.sh/docs/helm/helm_completion/)

## Zadanie

### Add & search repo

```bash
helm repo add workshop https://maciejkra.github.io/helm/
helm repo update
helm search repo workshop
```

### Install chart — warianty

```bash
# Prosty install
helm install <release> workshop/hello-world -n <namespace>

# Auto-generowana nazwa release
helm install --generate-name workshop/hello-world -n <namespace>

# Upgrade-or-install (idempotent — bezpieczne w CI)
helm upgrade --install <release> workshop/hello-world -n <namespace>

# + auto-create namespace
helm upgrade --install <release> workshop/hello-world -n <namespace> --create-namespace

# + atomic (rollback przy fail)
helm upgrade --install --atomic <release> workshop/hello-world -n <namespace> --create-namespace
```

### Weryfikacja

```bash
helm ls -n <namespace>
kubectl get all -n <namespace>
kubectl get secrets -n <namespace>      # helm trzyma stan release w Secret
```

### Values

```bash
helm show values workshop/hello-world          # defaulty chartu
helm get values <release> -n <namespace>       # values aktualnego release
```

### Customize values

```bash
# Pojedyncza wartość
helm upgrade --install --atomic <release> workshop/hello-world -n <namespace> \
  --create-namespace --set <key>=<value>

# Z pliku
helm upgrade --install --atomic <release> workshop/hello-world -n <namespace> \
  --create-namespace -f values-custom.yaml
```

### Rollback

```bash
helm status <release> -n <namespace>
helm history <release> -n <namespace>
helm rollback <release> <revision> -n <namespace>
```

### Download chart (study source)

```bash
helm pull workshop/hello-world --untar=true
```

### Uninstall

```bash
helm uninstall <release> -n <namespace>
```

## Wyzwanie (task)

Zmień jakąś wartość w `workshop/hello-world`, zrób `helm upgrade`, sprawdź czy działa. Potem rollback przez:
```bash
helm history <release> -n <namespace>
helm rollback <release> <prev-revision> -n <namespace>
```

## Pytania kontrolne
1. Gdzie helm trzyma stan release? (Hint: Secret `sh.helm.release.v1.*` w namespace)
2. `helm upgrade` vs `kubectl apply` na wygenerowanym manifeście — dlaczego helm lepszy dla complex charts?
3. `--atomic` — czemu krytyczne w CI/CD?
4. Jak debugować błędy template'u przed install? (Hint: `helm template --debug`)

## Linki
- [Helm cheat sheet](https://helm.sh/docs/intro/cheatsheet/)
- [Helm quickstart](https://helm.sh/docs/intro/quickstart/)
- [Using Helm](https://helm.sh/docs/intro/using_helm/)
- [Charts](https://helm.sh/docs/topics/charts/)
