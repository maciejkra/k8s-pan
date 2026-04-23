# Zadanie

## Część 1 — Install Gatekeeper (z mutation enabled)

```bash
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm repo update
helm install gatekeeper gatekeeper/gatekeeper \
  -n gatekeeper-system --create-namespace \
  --set replicas=1 \
  --set enableMutation=true \
  --set controllerManager.logLevel=INFO \
  --version 3.18.0
kubectl wait --for=condition=Available -n gatekeeper-system deployment/gatekeeper-controller-manager --timeout=2m
```

## Część 2 — Validate: wymagany label `owner`

```bash
# ConstraintTemplate (klasa policy)
kubectl apply -f template-required-labels.yaml
kubectl get constrainttemplate

# Gatekeeper generuje CRD:
kubectl api-resources | grep -i k8srequiredlabels
# k8srequiredlabels   constraints.gatekeeper.sh/v1beta1   true   K8sRequiredLabels

# Constraint (instancja — parametry + match selector)
kubectl apply -f constraint.yaml
kubectl get k8srequiredlabels

# Test negative
kubectl apply -f bad-pod.yaml
# Spodziewane: admission webhook "validation.gatekeeper.sh" denied the request:
#   [require-owner-label] you must provide labels: {"owner"}

# Test positive
kubectl apply -f good-pod.yaml
# pod/good-pod created
```

## Część 3 — Audit istniejących zasobów

```bash
# Pody stworzone PRZED aplikacją Constraint są "grandfathered" (nie zablokowane)
# Ale Gatekeeper audit loop je raportuje:
kubectl get k8srequiredlabels require-owner-label -o yaml | yq '.status.violations'
# Lista Pod-ów bez `owner` label
```

Interval audytu: domyślnie 60s. Flags: `--audit-interval=30`.

## Część 4 — Dry-run mode (warn zamiast deny)

```bash
kubectl patch k8srequiredlabels require-owner-label --type=merge \
  -p '{"spec":{"enforcementAction":"dryrun"}}'

kubectl apply -f bad-pod.yaml
# Spodziewane: Pod zostaje utworzony (warning w Gatekeeper logs)
kubectl logs -n gatekeeper-system deploy/gatekeeper-controller-manager | grep -i violation | tail -5
```

## Część 5 — Mutation: auto-fill `owner=unknown`

Bez mutation: Pod bez `owner` = reject. Z mutation: Pod dostaje `owner=unknown` automatycznie, potem validation go akceptuje.

```bash
# 1. Wyłącz Constraint (żeby mutation mogło działać zanim validation zabije)
kubectl patch k8srequiredlabels require-owner-label --type=merge \
  -p '{"spec":{"enforcementAction":"dryrun"}}'

# 2. Aplikuj mutation
kubectl apply -f template-mutation-owner.yaml
kubectl get assignmetadata set-default-owner-label

# 3. Apply Pod bez owner
kubectl apply -f bad-pod.yaml
# Pod utworzony, sprawdź label:
kubectl get pod bad-pod -o jsonpath='{.metadata.labels}' | jq
# { ..., "owner": "unknown" }
```

## Część 6 — Pełna kombinacja: mutation + validation

Końcowy stan:
- Mutation: wstrzykuje `owner=unknown` jeśli brak → **każdy Pod** dostaje jakąś wartość.
- Validation: wymaga label `owner` → PRZECHODZI (bo mutation właśnie dodał).

Wynik: nie ma Pod-ów bez `owner`. User pisze YAML bez labela, Gatekeeper dba o resztę.

Włącz Constraint z powrotem:
```bash
kubectl patch k8srequiredlabels require-owner-label --type=merge \
  -p '{"spec":{"enforcementAction":"deny"}}'
```

## Część 7 — Cleanup

```bash
kubectl delete -f . --ignore-not-found
helm uninstall gatekeeper -n gatekeeper-system
```

## Pytania

1. **Validate vs Mutate** — kiedy które? (Podaj po 2 konkretne scenariusze.)
2. **Rego** — pokaż Rego expression dla "Pod NIE może używać image: latest".
3. **`enforcementAction`** — `deny`, `dryrun`, `warn` — jak to różni się od failurePolicy w standardzie Webhook?
4. **Gatekeeper audit vs admission** — dlaczego audit raportuje a admission reject?
5. **Bonus**: **Constraint dry-run → deny transition** — jak bezpiecznie wprowadzać policy w działającym klastrze? (Hint: start od dryrun, obserwuj violations 1 tydzień, potem deny.)
