# Solution — 09_opa_gatekeeper

## Spodziewane wyniki

```bash
$ kubectl apply -f bad-pod.yaml
Error from server (Forbidden): error when creating "bad-pod.yaml": admission webhook "validation.gatekeeper.sh" denied the request: [require-owner-label] you must provide labels: {"owner"}

$ kubectl apply -f good-pod.yaml
pod/good-pod created
```

## Odpowiedzi

### enforcementAction: dryrun
Gatekeeper nie blokuje — tylko **loguje** naruszenia do `Constraint.status.violations` i metryki Prometheus. Użycie:
- **Rollout nowej policy** — najpierw dryrun, sprawdzić ile zasobów by failowało, potem deny
- **Continuous compliance** — wiele organizacji woli detekcję + alert niż deny (bo deny może blokować deploy w środku nocy)
- **Migration** — istniejące zasoby grandfathered, nowe wymuszone (kombinacja: dryrun dla starych namespace, deny dla nowych)

`warn` (od Gatekeeper 3.10) — Pod jest dopuszczony, ale `kubectl apply` zwraca warning.

### Validating vs Mutating
- **Validating** (default) — admission decision: allow/deny. Resource pozostaje niezmieniony.
- **Mutating** (od Gatekeeper 3.7+) — modyfikuje resource przed apply (np. dodaje brakujący label automatycznie). Wymaga `--enable-mutation=true`.

Mutation w Gatekeeper:
```yaml
apiVersion: mutations.gatekeeper.sh/v1
kind: Assign
metadata:
  name: add-default-owner
spec:
  applyTo: [{groups: [""], kinds: [Pod], versions: [v1]}]
  match: {scope: Namespaced}
  location: "metadata.labels.owner"
  parameters:
    assign:
      value: "team-unknown"
```

### Audit Interval
Gatekeeper okresowo (default 60s) skanuje **istniejące** zasoby przeciwko constraintom. Wynik → `Constraint.status.violations`.

Real-time nie ma sensu: 
- Admission webhook już jest real-time dla **nowych** zasobów
- Audit jest dla **wcześniej istniejących** + zasobów modyfikowanych przez kontrolery (np. status updates)
- Real-time scan 10000 Podów co sekundę = kill controller-manager

### ConstraintTemplate vs CRD
**Tak** — ConstraintTemplate jest CRD który **generuje** kolejny CRD. To meta-CRD pattern.

Gatekeeper:
1. Czyta ConstraintTemplate `k8srequiredlabels`
2. Tworzy CRD `k8srequiredlabels.constraints.gatekeeper.sh`
3. User tworzy `K8sRequiredLabels` resource (parametry + selector)
4. Gatekeeper rejestruje admission webhook dla tego resource

## Walidacja

```bash
$ kubectl get k8srequiredlabels require-owner-label -o yaml | yq '.status'
auditTimestamp: "2026-04-17T10:30:00Z"
byPod:
  - id: gatekeeper-controller-manager-...
    observedGeneration: 1
    operations: [audit, status, webhook]
totalViolations: 0
violations: []
```

## Praktyczne policies do wdrożenia w produkcji

Z biblioteki [open-policy-agent/gatekeeper-library](https://github.com/open-policy-agent/gatekeeper-library):
- `K8sBlockNodePort` — zakaz Service typu NodePort
- `K8sRequiredProbes` — wszystkie kontenery muszą mieć liveness + readiness
- `K8sContainerLimits` — limits CPU/memory są obowiązkowe
- `K8sAllowedRepos` — obrazy tylko z zaufanych registries (np. `ghcr.io/myorg/`, `gcr.io/myorg/`)
- `K8sBlockLoadBalancer` — zakaz Service LoadBalancer (control kosztów chmury)
- `K8sUniqueIngressHost` — żadne dwa Ingress nie mogą używać tego samego hosta

Cross-link: D4/12 supply_chain pokazuje policy "tylko podpisane obrazy" — kombinacja Gatekeeper + Cosign.
