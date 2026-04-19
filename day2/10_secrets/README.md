# 10 — Secrets (generic, docker-registry, tls)

## Cel
Stworzyć Secrets różnych typów i bezpiecznie je konsumować w Pod (env vars + mounted files). Zrozumieć dlaczego K8s Secrets to NIE jest pełne rozwiązanie security i kiedy iść w stronę Vault / SOPS / Sealed Secrets.

## Kontekst
**Secret** = analogiczne do ConfigMap, ale dla danych wrażliwych. **Domyślnie NIE jest szyfrowany** w etcd (tylko base64 encoded — nie myl z encryption!).

Typy Secret:
- `Opaque` (`generic`) — dowolne klucz-wartość (default)
- `kubernetes.io/dockerconfigjson` (`docker-registry`) — credentials do prywatnego rejestru obrazów
- `kubernetes.io/tls` (`tls`) — cert + klucz prywatny dla TLS (Ingress, Gateway API)
- `kubernetes.io/service-account-token` — auto-generowane dla SA
- `kubernetes.io/basic-auth`, `kubernetes.io/ssh-auth`

W produkcji **K8s Secrets nie wystarcza** — etcd encryption at rest + RBAC + Vault/SOPS to minimum.

## Prereqs
- K3d/Kind cluster

## Zadanie

### Generic Secret

1. Stwórz z plików i literałów:
   ```bash
   kubectl create secret generic my-secret \
     --from-file=./my-secrets \
     --from-literal=user=maciek
   ```

2. Sprawdź zawartość (base64!):
   ```bash
   kubectl get secret my-secret -o yaml
   echo "$(kubectl get secret my-secret -o jsonpath='{.data.user}' | base64 -d)"
   ```

### Docker Registry Secret (private images)

```bash
kubectl create secret docker-registry my-registry-secret \
  --docker-server=ghcr.io \
  --docker-username=<USERNAME> \
  --docker-password=<TOKEN_OR_PAT> \
  --docker-email=<EMAIL>

# Użycie w Pod:
# spec:
#   imagePullSecrets:
#     - name: my-registry-secret
```

### TLS Secret (dla Gateway API / Ingress)

```bash
kubectl create secret tls my-tls-secret \
  --cert=./server.crt \
  --key=./server.key
# Użycie: certificateRefs.name: my-tls-secret w listener Gateway (D2/07)
```

## Pytania kontrolne
1. Czemu K8s Secrets są tylko base64, nie zaszyfrowane?
2. Jak włączyć **encryption at rest** w etcd? (`--encryption-provider-config`)
3. Vault (D4/04) vs SOPS vs Sealed Secrets — kiedy które?
4. `imagePullSecrets` per Pod vs `imagePullSecrets` na ServiceAccount — która opcja?

## Linki
- [Secret docs](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Distribute credentials securely](https://kubernetes.io/docs/tasks/inject-data-application/distribute-credentials-secure/)
- [Pull image from private registry](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/)

## Alternatywy / dobre praktyki produkcyjne
- [HashiCorp Vault](https://www.vaultproject.io) — patrz **D4/04**
- [getsops/sops](https://github.com/getsops/sops) — szyfrowane YAML w Git, decrypt przy `kubectl apply`
- [bitnami-labs/sealed-secrets](https://github.com/bitnami-labs/sealed-secrets) — encrypted Secrets w Git, decrypt przez controller w klastrze
