# 03 — Admission Controllers (built-in + Webhook + VAP)

## Cel
Zrozumieć etap **Admission** w API request lifecycle: po AuthN/AuthZ, przed persistence w etcd. Poznać typy: built-in, ValidatingWebhookConfiguration, MutatingWebhookConfiguration, ValidatingAdmissionPolicy (CEL).

## Kontekst
Pełny flow K8s API request:
```
Request → AuthN → AuthZ → Mutating Admission → Schema validation → Validating Admission → etcd
```

**Admission Controllers** = "ostatnie słowo" przed zapisem do etcd. Mogą:
- **Mutate** — modyfikować obiekt (np. inject sidecar — Istio robi to; Vault Injector — D4/04)
- **Validate** — odrzucić obiekt (np. wymaga label, sprawdza policy)

Trzy podejścia:

| | Implementacja | Performance | Kiedy |
|---|---|---|---|
| **Built-in** | Zaszyte w kube-apiserver (Go) | Najszybsze | ResourceQuota, PSA (D4/02), LimitRanger, ServiceAccount |
| **Webhook** (Validating/Mutating) | HTTP call do external service | +10-100ms latency | OPA/Gatekeeper, Kyverno, Vault Injector, Istio sidecar |
| **ValidatingAdmissionPolicy (VAP) + CEL** | In-cluster, CEL evaluated by apiserver | Prawie jak built-in | K8s 1.30+ stable; proste validation without external dep |
| **MutatingAdmissionPolicy (MAP) + CEL** | Jak VAP + mutation | Alpha/beta 1.32-1.33 | Eksperymentalne; do obserwowania |

### VAP vs Webhook — pros/cons

| | VAP + CEL | ValidatingWebhookConfiguration |
|---|---|---|
| External dependency | nie | tak (webhook service musi być up) |
| TLS certs management | nie | tak (Gatekeeper chart generuje self-signed) |
| Mutacja | nie (tylko validate) | tak (Mutating webhook) |
| Custom logic (np. lookup in ConfigMap) | ograniczone do CEL | dowolne Go/Python/Rego |
| Failure mode | CEL error = klaster nie zapisuje request | webhook timeout → wg `failurePolicy` |
| HA | zero config | webhook replica HA + network |

**Zasada**: VAP dla prostych policy (runAsNonRoot, required labels). Webhook dla complex (Rego w OPA, policy z external DB lookup).

## Prereqs
- K3s / Kind / K3d cluster z K8s ≥1.30 (dla VAP stable — `admissionregistration.k8s.io/v1`)

## Pliki

- `VAP.yaml` — ValidatingAdmissionPolicy + Binding (namespace `maciek`)
- `deployment-example.yaml` — Deployment który PRZEJDZIE (hardened)
- `bad-deployment.yaml` — Deployment który ZOSTANIE ODRZUCONY (missing securityContext, cpu limit)

## Zadanie

Patrz [`task.md`](./task.md).

## Linki
- [Admission Controllers reference](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/)
- [Dynamic Admission Control (webhooks)](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/)
- [ValidatingAdmissionPolicy + CEL](https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy/)
- [CEL spec](https://github.com/google/cel-spec/blob/master/doc/langdef.md)

## Worth checking
- **MutatingAdmissionPolicy** (beta 1.33+) — podobny VAP ale z mutacją (eksperymentalne w 2026). Feature gate: `MutatingAdmissionPolicy=true`.
- **`paramKind`** — VAP może brać ConfigMap jako parametry, co pozwala reużyć policy z różnymi wartościami per-binding.
- [Kyverno](https://kyverno.io) — alternatywa OPA, YAML zamiast Rego, native dla K8s.
- [Open Policy Agent](https://www.openpolicyagent.org) — patrz D4/09 dla pełnego ćwiczenia.
