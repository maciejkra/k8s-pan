# Solution — 03_Admission_Controllers

## Odpowiedzi

### VAP vs Webhook

**VAP lepszy (3 sytuacje):**

1. **Simple policy** bez external lookups (np. "Deployment musi mieć ≥2 replik"). Każda webhook'owa instalacja ma komplikację TLS + HA + monitoring; VAP to 1 manifest.
2. **Niska latencja wymagana** — VAP evaluated by apiserver in-process; webhook dodaje 10-100ms per request.
3. **Wysoka niezawodność** — webhook service crash = admission fails (jeśli `failurePolicy: Fail`) albo przepuszcza (jeśli `Ignore`, niebezpieczne). VAP nie ma external dep.

**Webhook lepszy (2 sytuacje):**

1. **Custom logic w języku Go/Python/Rego** — np. OPA/Gatekeeper z Rego policy, Kyverno z YAML templating. CEL jest ograniczony.
2. **Mutation required** — VAP tylko validuje. Webhook z Mutating może zmienić obiekt (np. inject sidecar).

### Mutating vs Validating w prod

**Mutating**:
- Sticky — klient nie widzi że coś zostało dodane. `kubectl apply` + `kubectl get` = różne manifesty (spec.template dopisany Vault Agent sidecar).
- "Surprise" przy debug — "dlaczego mój Pod ma 3 kontenery gdy YAML mówił 1?".
- Ordering jest ważny — multiple mutating webhooks tworzą kolejne modifikacje.

**Validating**:
- Transparentne — pokazuje błąd, admission reject.
- Bezpieczniejsze operacyjnie.
- Nie tworzy drift między "manifest w Git" a "runtime state".

**Zasada**: mutacja dla infrastruktury klastrowej (Istio sidecar, Vault Agent) — zespół platform zarządza. Validation dla policy enforcement — zespół security.

### `failurePolicy: Fail` vs `Ignore`

Dotyczy Webhooks (nie VAP):
- **Fail**: webhook nie odpowiada w 10s → admission blokuje request (`Error: Internal error ... timeout`). Bezpieczne ale klaster potrafi "zaciąć się" gdy webhook service pada.
- **Ignore**: webhook timeout → admission akceptuje request (jak gdyby webhook dał OK). Niebezpieczne — w razie padnięcia webhook cały policy jest de facto wyłączony.

VAP nie ma tego problemu — evaluation jest lokalne w apiserver.

W produkcji:
- **PSA-like** (security) → `Fail` (lepiej block niż pozwolić na naruszenie).
- **Istio sidecar** (infrastruktura) → `Ignore` (lepiej Pod startuje bez sidecar niż zaszyty workload).

### paramKind — przykład użycia

Zobacz Przykład w task.md. Użycie: jedna VAP policy "allowed-images" + multiple ConfigMaps per środowisko:
- `allowed-images-prod` — tylko ghcr.io/myorg/ i gcr.io/myproject/
- `allowed-images-dev` — dodatkowo allowed Docker Hub

Multiple Bindings używają tej samej polityki z różnymi parametrami. DRY.

### MutatingAdmissionPolicy — use case

Prosty: inject label `managed-by: platform-team` do każdego Deployment. Zamiast Gatekeeper MutatingPolicy + Rego, wystarczy CEL-based MAP:

```yaml
apiVersion: admissionregistration.k8s.io/v1beta1   # beta w 1.33
kind: MutatingAdmissionPolicy
spec:
  matchConstraints: { resourceRules: [...] }
  mutations:
    - patchType: ApplyConfiguration
      applyConfiguration:
        expression: |
          Object{
            metadata: Object.metadata{
              labels: {"managed-by": "platform-team"}
            }
          }
```

Feature gate: `--feature-gates=MutatingAdmissionPolicy=true` + `--runtime-config=admissionregistration.k8s.io/v1beta1=true`.

W 2026 beta w 1.33+. Produkcyjnie czekaj na GA (1.34 lub 1.35).

## Walidacja

```bash
kubectl create namespace maciek
kubectl apply -f VAP.yaml

# Bad deployment — reject
kubectl apply -f bad-deployment.yaml
# Error: ValidatingAdmissionPolicy: violations ... all containers must set runAsNonRoot ...

# Good deployment — accept
kubectl apply -f deployment-example.yaml
kubectl wait --for=condition=available deployment/good-app -n maciek --timeout=30s

# Patch do violation
kubectl patch deploy good-app -n maciek --type=json -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/resources/limits/cpu","value":"1"}
]'
# Error: Containers must not set CPU limits
```

## Troubleshooting

### "ValidatingAdmissionPolicy not found"

Klaster K8s <1.30. Sprawdź:
```bash
kubectl version --short
```
Dla <1.30 użyj `admissionregistration.k8s.io/v1beta1` lub `v1alpha1`.

### CEL runtime error "no such key"

Brak guardu `has()`. CEL nie skraca — `has(c.resources.limits.cpu)` gdy `c.resources.limits` nie istnieje → throw. Zawsze:
```
has(c.resources) && has(c.resources.limits) && has(c.resources.limits.cpu)
```

### VAP nie triggeruje

Sprawdź binding `namespaceSelector`:
```bash
kubectl describe vap-binding pod-security-binding-maciek
kubectl get ns maciek --show-labels
# Musi mieć label kubernetes.io/metadata.name=maciek (auto-dodawany od K8s 1.21)
```

### `paramRef` nie znajdzie ConfigMap

ConfigMap musi istnieć w namespace podanym w `paramRef`. Sprawdź:
```bash
kubectl get cm -n kube-system allowed-images-config
```

## Cross-link

- D4/02 (PSA) — built-in admission; VAP to alternatywa dla customowych policy
- D4/09 (OPA/Gatekeeper) — Webhook-based, Rego; VAP vs OPA decision matrix w tych solution
- D4/04 (Vault Agent Injector) — classic MutatingWebhook example
- D3/02 (Resource Quota / Limit Range) — built-in admission (nie webhook), zobacz jak wygląda "prostszy" policy
- Presentation slajd 52 (OPA/Gatekeeper) — tu admission webhook w akcji
