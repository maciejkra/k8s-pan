# 05 — ConfigMap (env vars + zamontowane pliki)

## Cel
Wstrzyknąć konfigurację do Pod jako env variables i jako pliki (mount). Zobaczyć auto-update plików ConfigMap przy edycji.

## Kontekst
**ConfigMap** = key-value store K8s dla nie-sekretnej konfiguracji aplikacji. Dwa sposoby konsumpcji w Pod:
1. **env vars** — `valueFrom.configMapKeyRef`. Statyczne — zmiana ConfigMap NIE update'uje running Pod.
2. **volumes (mount jako pliki)** — `configMap.name`. **Auto-refresh** (~60s opóźnienia) — pliki w `/etc/config/` się zmieniają w runtime.

Dla większości aplikacji wybór: **mount jako pliki** + reagowanie na zmianę pliku (watch + reload). Dla starszych aplikacji bez reload: env vars + restart Pod-a po zmianie.

[`stakater/Reloader`](https://github.com/stakater/Reloader) — operator który automatycznie restartuje Deploymenty gdy ich ConfigMap/Secret się zmieni.

## Prereqs
- K3d/Kind cluster

## Zadanie

### Pod z ConfigMap jako env vars

1. Wdroż:
   ```bash
   kubectl apply -f pod-config.yaml
   kubectl logs configmap-pod
   kubectl logs configmap-pod | grep line
   ```

### Pod z ConfigMap zamontowanym jako pliki

1. Wdroż:
   ```bash
   kubectl apply -f pod-config-volume.yaml
   kubectl logs configmap-volume-pod
   ```

### Auto-update mounted ConfigMap

1. Edytuj ConfigMap w runtime:
   ```bash
   kubectl edit configmap configuration
   # Zmień wartość service-b.config
   ```

2. Czekaj ~60s i obserwuj:
   ```bash
   kubectl logs -f configmap-volume-pod
   # Zobaczysz że pliki się zmieniły (jeśli aplikacja je odczytuje na bieżąco)
   ```

## Pytania kontrolne
1. Dlaczego env vars **nie** auto-update'ują się przy zmianie ConfigMap?
2. Jak aplikacja może "zauważyć" zmianę zamontowanego pliku? (Hint: inotify, polling)
3. Stakater Reloader — jak działa? (Hint: hash w annotations + rollout)
4. Co z **mocno** dynamiczną konfiguracją (zmienia się co sekundę)? (Hint: nie ConfigMap, użyj feature flag service)

## Linki
- [ConfigMap docs](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Reloader](https://github.com/stakater/Reloader)
- [Configure a Pod to Use a ConfigMap](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/)
