# Solution — 02_psa_security

## Odpowiedzi

### PSA vs PSP

**PodSecurityPolicy (PSP)** — deprecated w 1.21, usunięty w 1.25. Problemy:
- Policy = CRD, RBAC-gated (SA musi mieć RBAC żeby "use" policy) — mechanizm brittle, łatwo źle skonfigurować.
- Ordering niezdefiniowane (gdy multiple PSP matchują, który wygrywa?).
- Brak granularity per-mode (PSP było enforce-only).

**PSA** — prostsze:
- Policy = 3 standardy (privileged/baseline/restricted) — no custom.
- Label na NS = config. Trivial RBAC (tylko `update namespaces`).
- Trzy mode (enforce/audit/warn) niezależne.

Tradeoff: PSA jest LESS flexible. Dla custom policies → OPA/Gatekeeper (D4/09) lub Kyverno.

### `enforce-version: latest` vs konkretna

`latest` = "interpretuj label przez wersję K8s którą masz teraz". Upgrade K8s → restrictedness się zmienia (np. 1.27 dodała wymaganie seccompProfile dla baseline).

**Konkretna** (`v1.30`) = stabilny kontrakt przy upgrade. Pod który dziś przechodzi, po upgrade K8s nadal przechodzi (bo evaluated przeciwko 1.30 standardowi).

Produkcja: używaj konkretnej wersji (`v1.30`, `v1.31`) żeby uniknąć surprise'ów przy K8s upgrade. Developer NS: `latest` — zachęca do trzymania hardening na bieżąco.

### Controller-level trap — CI/CD prevention

1. **`kubectl apply --dry-run=server --validate=true`** — wykonuje admission check (łącznie z PSA) bez faktycznego apply. `--dry-run=server` ≠ `client` — server dry-run widzi PSA webhook. CI pipeline: jeśli dry-run fail → blokuj merge.
2. **`kubectl wait --for=condition=Available deployment/X --timeout=2m`** po apply → jeśli timeout, zgłoś error. Łapie trap post-apply.
3. **Argo CD / Flux** auto-sync — widzi "Degraded" stan gdy Deployment.Available<Desired + pokazuje błędy z ReplicaSet events.
4. **OPA/Gatekeeper + pre-merge check** — policy "Deployment's spec.template musi spełniać PSA level NS w którym jest deploy'owany" → zweryfikować manifestu w Git zanim merge.

### PSA + Vault injector

Vault Agent Injector wstrzykuje:
- **initContainer `vault-agent-init`** — uruchamia się jako root (wymaga `runAsUser` dla dostępu do Vault tokena).
- **sidecar `vault-agent`** — jako root lub określony user.

W `enforce: restricted`:
- initContainer bez `runAsNonRoot` → odrzucony.
- Fix: Vault chart ma `injector.agentImage.securityContext` values — ustaw `runAsUser: 100, runAsGroup: 1000, runAsNonRoot: true`.

Ale: jeśli Pod userski ma `runAsUser: 100`, a Vault token owner to `100` — file ownership conflict. W praktyce: dev używa Vault w `psa-baseline` albo daje mniej restrictive policy.

### Default PSA per NS

Bez labelów NS — PSA traktuje NS jako `privileged` (czyli: bez ograniczeń). Odwrócone założenie vs. niektóre platformy (OpenShift default restricted).

Wyjątek: `kube-system` ma domyślnie `privileged` i nie należy tego zmieniać (system Pody jak CoreDNS, kube-proxy używają hostPath, hostNetwork, privileged).

**Zalecenie prod**: default-deny. Ustaw kube-apiserver flagi:
```
--admission-control-config-file=/etc/k8s/psa-config.yaml
```
Z configem:
```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
  - name: PodSecurity
    configuration:
      apiVersion: pod-security.admission.config.k8s.io/v1
      kind: PodSecurityConfiguration
      defaults: { enforce: "baseline", enforce-version: "latest" }
      exemptions:
        namespaces: ["kube-system"]
```

## Walidacja

```bash
kubectl apply -f ns.yaml

# Baseline — nginx root OK (ale warning)
kubectl apply -f deployment-baseline.yaml 2>&1 | grep -i warning
# Warning: would violate PodSecurity "restricted:latest": ...
kubectl get pods -n psa-baseline
# myapp-xxx  1/1   Running

# Restricted — bad-pod REJECTED
kubectl apply -f bad-pod-restricted.yaml 2>&1 | grep -i forbidden
# Error from server (Forbidden): ... violates PodSecurity "restricted:latest"

# Restricted — hardened OK
kubectl apply -f hardened-pod-restricted.yaml
kubectl wait --for=condition=ready pod/hardened-pod -n psa-restricted --timeout=30s

# Trap — Deployment created, 0/3 ready
kubectl apply -f deployment-controller-trap.yaml
sleep 5
kubectl get deploy -n psa-restricted trap
# READY: 0/3

kubectl describe rs -n psa-restricted -l app=trap | grep -A 3 FailedCreate
# Error creating: pods "trap-xxx" is forbidden: violates PodSecurity "restricted"
```

## Troubleshooting

### `nodes.metrics.k8s.io is forbidden: User "system:node:X" cannot list resource`

Inny problem (RBAC, nie PSA). Ignoruj dla tego ćwiczenia.

### `Warning` show'd but Pod creates

`warn`/`audit` tylko obserwują, nie blokują. Tylko `enforce` blokuje. Sprawdź labele NS:
```bash
kubectl get ns <ns> -o jsonpath='{.metadata.labels}' | jq
```

### Restricted NS + `kubectl run X --image=nginx` przeszło

`kubectl run` bez `--restart=Never` domyślnie tworzy Deployment → controller-level trap. Sprawdź `kubectl get pods`.

### NS bez labelów PSA — co blokuje?

Nic, default privileged. Jeśli chcesz default baseline dla klastra — włącz PSA admission config przez kube-apiserver flag.

## Cross-link

- D4/03 (Admission Controllers) — PSA to built-in admission; Admission Webhooks to external
- D4/05 (SecurityContext) — POD-level security settings; PSA enforces je per-namespace
- D4/09 (OPA/Gatekeeper) — alternatywa dla PSA gdy chcesz custom policy
- D4/04 (Vault) — Vault injector vs restricted PSA (wymaga dostrojenia)
- D1/06 (hardening Dockerfile) — obraz non-root jest prereq dla PSA restricted
