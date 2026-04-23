# Zadanie

## Część 1 — Install Vault + CSI Driver

```bash
# Vault w dev mode
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
helm upgrade --install vault hashicorp/vault --version 0.30.0 \
  --create-namespace -n vault \
  -f vault-values.yaml
kubectl wait --for=condition=ready pod/vault-0 -n vault --timeout=120s

# CSI Secrets Store driver (potrzebny dla wzorców 1-2)
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm upgrade --install csi-secrets-store \
  secrets-store-csi-driver/secrets-store-csi-driver \
  -n kube-system --set syncSecret.enabled=true
```

## Część 2 — Skonfiguruj Vault (Kubernetes auth + secret + policy + role)

```bash
# Wejdź do poda vault-0
kubectl exec -it -n vault vault-0 -- sh

# Włącz k8s auth method
vault auth enable kubernetes

# Skonfiguruj auth — vault uses kube-apiserver jako identity provider
vault write auth/kubernetes/config \
  kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443"

# Dodaj secret przez CLI (NIE przez UI — IaC-friendly)
vault kv put secret/db-pass password=supersecret-change-me
vault kv get secret/db-pass
# ========= Secret Path =========
# secret/data/db-pass
# ======= Metadata =======
# ...
# === Data ===
# password    supersecret-change-me

# Policy — kto może czytać ten secret
vault policy write internal-app - <<EOF
path "secret/data/db-pass" {
  capabilities = ["read"]
}
EOF

# Role — wiąże ServiceAccount z policy
vault write auth/kubernetes/role/database \
  bound_service_account_names=app-sa \
  bound_service_account_namespaces=default \
  policies=internal-app \
  ttl=20m

exit
```

## Część 3 — Wzorzec 1: CSI Secrets Store (volume mount)

```bash
kubectl apply -f csisecret.yaml
kubectl apply -f csi-pod.yaml
kubectl wait --for=condition=ready pod/webapp --timeout=60s

kubectl exec -it webapp -- cat /mnt/secrets-store/db-password
# supersecret-change-me
```

**Observacja**: secret jest dostępny tylko jako plik (volume mount). Aplikacja musi czytać plik albo parsować.

## Część 4 — Wzorzec 2: CSI + sync do K8s Secret (env)

```bash
kubectl apply -f csisecret-env.yaml
kubectl apply -f csi-pod-env.yaml
kubectl wait --for=condition=ready pod/webapp-env --timeout=60s

# K8s Secret został zrefleksowany z Vault secret
kubectl get secret dbpass -o jsonpath='{.data.password}' | base64 -d
# supersecret-change-me

kubectl exec -it webapp-env -- sh -c 'echo $DB_PASSWORD'
# supersecret-change-me
```

**Observacja**: aplikacja widzi env var bez żadnych zmian — standardowy `secretKeyRef`.

## Część 5 — Wzorzec 3: Agent Injector (sidecar)

```bash
kubectl apply -f inject-pod.yaml
kubectl wait --for=condition=ready pod/webapp-inject --timeout=60s

kubectl exec -it webapp-inject -c webapp -- cat /vault/secrets/database-config.txt
# supersecret-change-me
```

Sprawdź Pod strukturę:
```bash
kubectl get pod webapp-inject -o jsonpath='{.spec.initContainers[*].name}'
# vault-agent-init
kubectl get pod webapp-inject -o jsonpath='{.spec.containers[*].name}'
# webapp vault-agent
```

Są **dwa** dodatkowe kontenery (init + sidecar) — injector je wstrzyknął przez MutatingAdmissionWebhook.

## Część 6 — Update secret (demo rotacji)

```bash
# Zmień wartość w Vault
kubectl exec -it -n vault vault-0 -- vault kv put secret/db-pass password=NEW-SECRET

# Po ~60-120s CSI sync podniesie nowe
kubectl exec webapp -- cat /mnt/secrets-store/db-password
# NEW-SECRET (po chwili)

kubectl get secret dbpass -o jsonpath='{.data.password}' | base64 -d
# NEW-SECRET

# Agent Injector: rotate wymaga sidecar reload (niekoniecznie restart Pod-a, ale sidecar renew'uje lease)
```

## Część 7 — Cleanup

```bash
kubectl delete pod webapp webapp-env webapp-inject
kubectl delete sa app-sa
kubectl delete secretproviderclass vault-database vault-database-env
helm uninstall vault -n vault
helm uninstall csi-secrets-store -n kube-system
```

## Pytania

1. **3 wzorce** — kiedy który? (Hint: volume dla cert/key, env dla legacy aplikacji, injector dla multi-env templating.)
2. **CSI vs Injector** — oba wymagają roll of Pod dla rotacji? (Hint: nie — CSI auto-refreshuje volume.)
3. **`bound_service_account_namespaces`** — dlaczego scope do namespace, nie tylko po SA name?
4. **K8s 1.24+ legacy SA tokens** — dlaczego Vault k8s auth ma problem z K8s ≥1.24? Jak to obejść?
5. **Bonus**: Rollout SA credentials w Vault (rotate root token, regen unseal keys) — sketchuj workflow.

## Bonus — External Secrets Operator (ESO)

Przykład alternatywy bez Vault:

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets --create-namespace
```

Prosty flow z provider `kubernetes` (secret w innym NS jako source):

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata: { name: k8s-backend }
spec:
  provider:
    kubernetes:
      remoteNamespace: secrets-source
      server: { caProvider: { type: ConfigMap, name: kube-root-ca.crt } }
      auth: { serviceAccount: { name: eso-reader } }
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata: { name: db-pass-from-secrets-source }
spec:
  refreshInterval: 1h
  secretStoreRef: { name: k8s-backend, kind: SecretStore }
  target: { name: db-pass, creationPolicy: Owner }
  data:
    - secretKey: password
      remoteRef: { key: db-pass, property: password }
```

ESO stworzy Secret `db-pass` który możesz konsumować jak zwykły K8s Secret. **Bez sidecar, bez CSI driver**.
