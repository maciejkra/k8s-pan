# 09 — OPA / Gatekeeper: policy as code

## Cel
Wymusić w klastrze policy "każdy Pod musi mieć label `owner`" przez OPA/Gatekeeper. Zobaczyć różnicę admission validate / mutate i jak ConstraintTemplate generuje custom CRD-y.

## Kontekst
[OPA (Open Policy Agent)](https://www.openpolicyagent.org/) to general-purpose policy engine z językiem Rego. W K8s używany przez **Gatekeeper** — admission controller który:
1. Przyjmuje `ConstraintTemplate` (CRD definiujący nową klasę policy + Rego logika)
2. Generuje z niej nowy CRD (np. `K8sRequiredLabels`)
3. Przyjmuje `Constraint` instance tego CRD (parametry policy + selector zasobów)
4. Dla każdego AdmissionRequest pasującego do selector wykonuje Rego → allow / deny

**Alternatywy**:
- **Kyverno** — natywny dla K8s, YAML zamiast Rego, prostszy. Często wybierany w nowych klastrach.
- **PSA** (D4/02) — wbudowane w K8s, ale tylko Pod Security Standards (3 fixed levels). OPA pokrywa znacznie więcej.

## Prereqs
- K3d cluster

## Zadanie

### Część 1 — instalacja

```bash
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm repo update
helm install gatekeeper gatekeeper/gatekeeper \
  -n gatekeeper-system --create-namespace \
  --set replicas=1 \
  --version 3.16.3
kubectl wait --for=condition=Available -n gatekeeper-system deployment/gatekeeper-controller-manager --timeout=2m
```

### Część 2 — ConstraintTemplate (definicja klasy policy)

```bash
kubectl apply -f template-required-labels.yaml
kubectl get constrainttemplate
# k8srequiredlabels (nowa klasa CRD)
kubectl api-resources | grep -i k8srequiredlabels
# k8srequiredlabels.constraints.gatekeeper.sh/v1beta1
```

### Część 3 — Constraint (instancja policy)

```bash
kubectl apply -f constraint.yaml
kubectl get k8srequiredlabels
```

### Część 4 — test

```bash
# Bad pod — bez labela `owner`
kubectl apply -f bad-pod.yaml
# Expected: Error from server: admission webhook "validation.gatekeeper.sh" denied the request:
#   [require-owner-label] you must provide labels: {"owner"}

# Good pod — z labelem
kubectl apply -f good-pod.yaml
# pod/good-pod created
```

### Część 5 — audit istniejących zasobów

Constraint zaaplikowany **po** istniejących zasobach? Gatekeeper nie usuwa, ale raportuje:
```bash
kubectl get k8srequiredlabels require-owner-label -o yaml | yq '.status.violations'
# Lista wszystkich Podów bez labela
```

### Część 6 — dry-run mode

```bash
kubectl patch k8srequiredlabels require-owner-label --type=merge \
  -p '{"spec":{"enforcementAction":"dryrun"}}'
kubectl apply -f bad-pod.yaml
# OK — Pod utworzony, naruszenie tylko logowane
kubectl logs -n gatekeeper-system deploy/gatekeeper-controller-manager | grep -i violation
```

## Bonus — Kyverno alternatywa

Ten sam policy w Kyverno jest jednoplikowy YAML (nie potrzebuje Rego):
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-owner-label
spec:
  validationFailureAction: Enforce
  rules:
    - name: check-owner
      match:
        any: [{ resources: { kinds: [Pod] } }]
      validate:
        message: "Pod musi mieć label 'owner'"
        pattern:
          metadata:
            labels:
              owner: "?*"
```

Kiedy OPA, kiedy Kyverno:
- **OPA** — masz już OPA w innym kontekście (CI policy, Terraform), chcesz spójność
- **Kyverno** — start od zera, prostsze use cases, mutate (np. dodaj label automatycznie) bardziej intuicyjny

## Pytania kontrolne
1. Co to jest `enforcementAction: dryrun`? Kiedy używać?
2. Validating vs Mutating admission webhook — Gatekeeper jest którym? (Hint: oba — Mutation dostępna od 3.x)
3. Audit Interval (default 60s) — czemu nie real-time?
4. ConstraintTemplate vs CRD — to jest CRD generujący CRD-y?

## Linki
- [Gatekeeper docs](https://open-policy-agent.github.io/gatekeeper/website/docs/)
- [Gatekeeper library](https://github.com/open-policy-agent/gatekeeper-library) — gotowe templates
- [Rego playground](https://play.openpolicyagent.org/)
