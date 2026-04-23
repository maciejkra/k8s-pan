# Solution — 09_opa_gatekeeper

## Odpowiedzi

### Validate vs Mutate

**Validate — kiedy:**
1. **Security hard enforcement** — "Pod nie może być privileged". Mutacja byłaby dziwna (fundamental violation).
2. **Required naming conventions** — "wszystkie Service muszą zaczynać się od `<team>-`". Easier do zrozumienia "reject + message" niż automatic rename.

**Mutate — kiedy:**
1. **Sensible defaults** — "jeśli Pod nie ma `runAsNonRoot`, dodaj go". Reduce friction dla devów.
2. **Standardized labels / annotations** — auto-doda `team=<owner>` na podstawie ServiceAccount. Dev nie musi pamiętać.
3. **Injection dla platform features** — auto-dodaj sidecar logging, metrics. (Istio injector jest dokładnie mutation.)

**Uwaga**: mutation jest "sticky" — klient nie widzi że coś zostało zmienione między `kubectl apply` a `kubectl get`. Łatwo kogoś zaskoczyć. Zawsze dokumentuj co Twoje policy mutacji robią.

### Rego dla "no :latest"

```rego
package k8snolatestimage

violation[{"msg": msg}] {
  input.review.kind.kind == "Pod"
  container := input.review.object.spec.containers[_]
  endswith(container.image, ":latest")
  msg := sprintf("Container %v używa image :latest — forbidden", [container.name])
}

violation[{"msg": msg}] {
  input.review.kind.kind == "Pod"
  container := input.review.object.spec.containers[_]
  not contains(container.image, ":")        # image bez tag = latest domyślnie
  msg := sprintf("Container %v nie ma tag-a (implicit :latest) — użyj explicit version", [container.name])
}
```

Użycie:
```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata: { name: k8snolatestimage }
spec:
  crd: { spec: { names: { kind: K8sNoLatestImage } } }
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        <tu powyższy Rego>
```

### enforcementAction vs failurePolicy

**`enforcementAction`** (Gatekeeper-specific):
- `deny` — odrzucaj request
- `dryrun` — pozwól, loguj violation (Gatekeeper status)
- `warn` — pozwól, daj warning w kubectl output (K8s 1.23+)

**`failurePolicy`** (standardowe Webhook):
- `Fail` — jeśli webhook nie odpowiada (timeout, crash), blokuj request
- `Ignore` — jeśli webhook nie odpowiada, pozwól

To inne rzeczy:
- `enforcementAction` = "co zrobić gdy policy się NIE zgadza"
- `failurePolicy` = "co zrobić gdy webhook się wywala"

### Audit vs Admission

**Admission** = real-time, per-request. Blokuje niewłaściwe CRUD operacje.

**Audit** = background loop (default 60s), skanuje istniejące zasoby pod kątem Constraints. Używa tego samego Rego, ale na cały klaster, nie per-request.

Po co audit? Gdy dodasz nowe Constraint, istniejące Pody (utworzone PRZED) nie są blokowane — są już w etcd. Audit raportuje co by było problemem:
```bash
kubectl get k8srequiredlabels require-owner-label -o yaml | yq '.status.violations'
```

### Dry-run → deny transition

Bezpieczne wprowadzenie nowej policy:

**Week 1**: Deploy Constraint z `enforcementAction: dryrun`. Zbieraj violations przez tydzień.
**Week 2**: Review violations, kontaktuj się z teamami którzy mają naruszenia.
**Week 3**: Gdy violations count <5, promo do `warn`. Devs teraz zobaczą warning w kubectl.
**Week 4**: `deny`. Nowe Pody muszą spełnić policy.

Monitoring: alert gdy `gatekeeper_violations{enforcement_action="dryrun"} > 0`.

## Walidacja

```bash
# Validate
kubectl apply -f template-required-labels.yaml
kubectl apply -f constraint.yaml
kubectl apply -f bad-pod.yaml
# denied the request: [require-owner-label] you must provide labels: {"owner"}

kubectl apply -f good-pod.yaml
# pod/good-pod created

# Mutate
kubectl patch k8srequiredlabels require-owner-label --type=merge -p '{"spec":{"enforcementAction":"dryrun"}}'
kubectl apply -f template-mutation-owner.yaml
kubectl apply -f bad-pod.yaml
kubectl get pod bad-pod -o jsonpath='{.metadata.labels.owner}'
# unknown (wstrzyknięte przez mutation)

# Combo
kubectl patch k8srequiredlabels require-owner-label --type=merge -p '{"spec":{"enforcementAction":"deny"}}'
kubectl delete pod bad-pod
kubectl apply -f bad-pod.yaml
# OK — mutation dodaje owner=unknown, validation widzi label i przepuszcza
```

## Troubleshooting

### `kind AssignMetadata not found`

Mutation nie jest włączone. Re-install Gatekeeper z `--set enableMutation=true`.

### Gatekeeper webhook timeout

```bash
kubectl logs -n gatekeeper-system deploy/gatekeeper-controller-manager | grep -i "too slow\|timeout"
```
Typowe: Rego expensive (O(n²) loop). Optymalizuj albo `validationActions: [Warn]` zamiast Deny.

### Nowa Constraint nie działa

```bash
# Czy webhook jest zarejestrowany?
kubectl get validatingwebhookconfiguration gatekeeper-validating-webhook-configuration

# Czy Gatekeeper widzi Constraint?
kubectl describe k8srequiredlabels require-owner-label | grep -A 5 "Status"
```

## Cross-link

- D4/02 (PSA) — built-in policy, zawsze gdzieś obok Gatekeeper
- D4/03 (Admission Controllers) — ogólny kontekst; Gatekeeper to jeden z webhook
- D4/05 (SecurityContext) — Gatekeeper może enforce SecurityContext fields
- Presentation slajd 52 (OPA/Gatekeeper) — teoria z praktycznym demo tu
