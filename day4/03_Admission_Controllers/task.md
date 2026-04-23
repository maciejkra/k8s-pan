# Zadanie

## Część 1 — Zobacz built-in admission w kube-apiserver

```bash
# Dla K3s — apiserver działa jako proces k3s, nie jako Pod
# Dla Kind / kubeadm — apiserver to Pod w kube-system
kubectl get pod -n kube-system -l component=kube-apiserver -o yaml 2>/dev/null | \
  grep -A 2 "enable-admission"
# --enable-admission-plugins=NodeRestriction,PodSecurity,...

# Lista wszystkich dostępnych (bez włączenia):
kubectl api-resources | grep admissionregistration
# validatingadmissionpolicies, validatingwebhookconfigurations, itp.
```

## Część 2 — Zobacz zarejestrowane webhooks

```bash
kubectl get validatingwebhookconfiguration
kubectl get mutatingwebhookconfiguration
# Na "czystym" klastrze: puste albo tylko system-generated (cert-manager webhook).
```

Po `helm install vault ...` (D4/04) lub `helm install gatekeeper ...` (D4/09) — nowe webhooks.

## Część 3 — Utwórz namespace + VAP

```bash
# 1. Namespace `maciek` (VAP binding matchuje label kubernetes.io/metadata.name=maciek,
#    który K8s auto-dodaje do każdego NS od 1.21)
kubectl create namespace maciek

# 2. VAP + Binding
kubectl apply -f VAP.yaml

# Weryfikacja:
kubectl get vap pod-security-maciek
kubectl get validatingadmissionpolicybinding pod-security-binding-maciek
```

## Część 4 — Negative test (bad-deployment ODRZUCONY)

```bash
kubectl apply -f bad-deployment.yaml
# Spodziewane:
#   Error from server: error when creating "bad-deployment.yaml":
#   admission webhook "validation.policy.admissionregistration.k8s.io/pod-security-maciek" denied the request:
#   all containers must set runAsNonRoot to true
#
#   (albo inny message z listy — VAP zwraca pierwszy violation)
```

Kolejno odkomentuj / dodaj pola żeby spełnić VAP — re-apply, obserwuj jak message się zmienia, aż Deployment zostanie zaakceptowany.

## Część 5 — Hardened Deployment PRZECHODZI

```bash
kubectl apply -f deployment-example.yaml
kubectl wait --for=condition=available deployment/good-app -n maciek --timeout=60s
kubectl get pod -n maciek -l app=good-app
# Running
```

## Część 6 — Eksperyment: dodaj CPU limit do good-app

```bash
kubectl patch deployment good-app -n maciek --type=json -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/resources/limits/cpu","value":"1"}
]'
# Spodziewany error: VAP message "Containers must not set CPU limits..."
```

## Część 7 — Widok działania w trybie `Warn` zamiast `Deny`

Zmień `validationActions: ["Warn"]` (zamiast `Deny`) → VAP pokaże warning ale pozwoli stworzyć obiekt:

```bash
kubectl patch validatingadmissionpolicybinding pod-security-binding-maciek --type=json -p='[
  {"op":"replace","path":"/spec/validationActions/0","value":"Warn"}
]'
kubectl apply -f bad-deployment.yaml
# "Warning: Validation failed for ValidatingAdmissionPolicy..."
# "deployment.apps/bad-app created" — ale tylko Deployment sam. Pody (jeśli enforce) mogą być blokowane osobno.
```

Cleanup:
```bash
kubectl delete ns maciek
```

## Pytania

1. **VAP vs ValidatingWebhookConfiguration** — wymień 3 sytuacje w których VAP jest **lepszy** i 2 w których webhook wygrywa.
2. **Mutating vs Validating** — co jest "bezpieczniejsze" w prod? (Hint: mutacja jest sticky — klient nie widzi że coś zostało zmienione; łatwo zaskoczyć.)
3. **`failurePolicy: Fail` vs `Ignore`** — dla VAP co znaczy i kiedy które?
4. **`paramKind`** — dodaj VAP który pobiera parametry z ConfigMap (np. `allowedImages`). Pokaż 5-wierszowy przykład.
5. **Bonus**: **MutatingAdmissionPolicy** (beta 1.33) — jaki byłby Twój pierwszy use case?

## paramKind example

VAP z parametryzowaną listą dozwolonych obrazów:

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata: { name: allowed-images }
spec:
  paramKind:
    apiVersion: v1
    kind: ConfigMap
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE"]
        resources: ["pods"]
  validations:
    - expression: "object.spec.containers.all(c, params.data.allowed.split(',').exists(img, c.image.startsWith(img)))"
      message: "Image must start with one of allowed prefixes from ConfigMap"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata: { name: allowed-images-binding }
spec:
  policyName: allowed-images
  paramRef:
    name: allowed-images-config
    namespace: kube-system
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels: { enforcement: "on" }
---
apiVersion: v1
kind: ConfigMap
metadata: { name: allowed-images-config, namespace: kube-system }
data:
  allowed: "ghcr.io/myorg/,gcr.io/myproject/"
```

Ten sam VAP z różnymi binding może mieć różne `allowedImages` per NS.
