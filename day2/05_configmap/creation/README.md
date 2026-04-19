# Creation — sposoby tworzenia ConfigMap

## Cel
Poznać 4 sposoby tworzenia ConfigMap i wiedzieć kiedy który jest właściwy.

## Kontekst
ConfigMap można tworzyć:
1. **Z plików w katalogu** (`--from-file=./`) — każdy plik jako osobny key
2. **Z env file** (`--from-env-file=`) — pary `KEY=VALUE` linia po linii
3. **Z konkretnego pliku z custom keyem** (`--from-file=mykey=path/to/file`)
4. **Z literałów** (`--from-literal=KEY=VALUE`)
5. **Z manifestu YAML** (`kubectl apply -f cm.yaml`) — najlepsze dla GitOps

Imperative methods (1-4) świetne dla quick prototyping; declarative (5) dla produkcji (audytowalność, code review).

## Prereqs
- K3d/Kind cluster

## Zadanie

### 1. Z katalogu (każdy plik = osobny key)

```bash
kubectl create configmap configuration --from-file=./
kubectl get configmap/configuration -o yaml
# Każdy plik z bieżącego katalogu trafił jako osobny `data.<filename>` key
```

### 2. Z env file

```bash
kubectl create configmap fromenv --from-env-file=env-file-example
kubectl get configmap/fromenv -o json
kubectl get configmap/fromenv -o yaml
# Każda linia "KEY=VALUE" trafiła jako osobny `data.KEY`
```

### 3. Z konkretnego pliku z custom keyem

```bash
kubectl create configmap test-config --from-file=s.json=service.json
kubectl get configmap/test-config -o yaml
# Tylko jeden klucz: s.json (zawartość = service.json)
```

### 4. Mix — kilka źródeł na raz

```bash
kubectl create configmap mixed \
  --from-file=service.json \
  --from-literal=ENV=production \
  --from-literal=DEBUG=false
kubectl get cm mixed -o yaml
```

## Pytania kontrolne
1. Co się stanie gdy plik ma binary content? Czy ConfigMap go obsłuży? (Hint: `binaryData`)
2. Limit rozmiaru ConfigMap? Co gdy potrzebuję 5MB config? (Hint: 1MB limit, użyj alternatives)
3. Imperative `kubectl create` vs declarative `kubectl apply` — który dla CI/CD?
4. Jak wersjonować ConfigMap (rolling out kolejnych wersji)? (Hint: versioned name + Reloader)

## Linki
- [Configure ConfigMap from files](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/#create-a-configmap)
