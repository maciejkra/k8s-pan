# 09 — OPA / Gatekeeper: policy as code (validate + mutate)

## Cel
Wymusić w klastrze dwa wzorce policy przez OPA/Gatekeeper:
1. **Validate**: "każdy Pod musi mieć label `owner`" — brak = reject.
2. **Mutate**: "Pod bez labela `owner` dostaje automatycznie `owner=unknown`".

Zobaczyć różnicę admission validate / mutate i jak ConstraintTemplate generuje custom CRD-y.

## Kontekst
[OPA (Open Policy Agent)](https://www.openpolicyagent.org/) to general-purpose policy engine z językiem **Rego**. W K8s używany przez **Gatekeeper** — admission controller który:
1. Przyjmuje `ConstraintTemplate` (CRD definiujący nową klasę policy + Rego logika)
2. Generuje z niej nowy CRD (np. `K8sRequiredLabels`)
3. Przyjmuje `Constraint` instance tego CRD (parametry policy + selector zasobów)
4. Dla każdego AdmissionRequest pasującego do selector wykonuje Rego → allow / deny

**Mutation** (od Gatekeeper 3.x) używa innego CRD: `AssignMetadata`, `Assign`, `ModifySet`. Bez Rego.

### Gatekeeper vs inne admission

| | Gatekeeper | Kyverno | VAP (D4/03) |
|---|---|---|---|
| Język | Rego | YAML | CEL |
| Mutation | tak | tak | nie (VAP), tak (MAP beta) |
| External dependency | webhook | webhook | nie |
| Reuse policies | OPA ecosystem | Kyverno Charts | CEL expression library (ograniczone) |
| Dojrzałość | starszy, bardziej dojrzały | młodszy, szybko rośnie | najnowszy, ograniczony |

**Praktyka 2026**:
- **OPA/Gatekeeper** — klastry korporacyjne już używające OPA gdzie indziej (CI policy, Terraform Sentinel alt).
- **Kyverno** — nowe klastry, zespoły bez Rego experience.
- **VAP** — proste policy + niski overhead (wbudowane w apiserver).

**PSA (D4/02)** zostaje dla podstaw security; OPA/Kyverno pokrywają wszystko inne.

## Prereqs
- K3s / Kind / K3d cluster

## Pliki

| Plik | Co |
|---|---|
| `template-required-labels.yaml` | ConstraintTemplate K8sRequiredLabels (Rego violation rule) |
| `constraint.yaml` | Constraint `require-owner-label` (instancja template, match=Pod w default) |
| `bad-pod.yaml` | Pod bez labela `owner` — odrzucony przez Constraint |
| `good-pod.yaml` | Pod z `owner=alice` — OK |
| `template-mutation-owner.yaml` | AssignMetadata mutation — auto-doda `owner=unknown` jeśli brakuje |

## Zadanie

Patrz [`task.md`](./task.md).

## Linki
- [Gatekeeper docs](https://open-policy-agent.github.io/gatekeeper/website/docs/)
- [Gatekeeper library](https://github.com/open-policy-agent/gatekeeper-library) — gotowe templates
- [Mutation docs](https://open-policy-agent.github.io/gatekeeper/website/docs/mutation/)
- [Rego playground](https://play.openpolicyagent.org/)
- [Kyverno comparison](https://neonmirrors.net/post/2021-09/kubernetes-policy-comparison-opa-gatekeeper-vs-kyverno/)
