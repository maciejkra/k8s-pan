# 03 — Admission Controllers

## Cel
Zrozumieć etap **Admission** w API request lifecycle: po AuthN/AuthZ, przed persistence w etcd. Poznać typy: built-in, ValidatingWebhookConfiguration, MutatingWebhookConfiguration, ValidatingAdmissionPolicy (CEL).

## Kontekst
Pełny flow K8s API request:
```
Request → AuthN → AuthZ → Admission (mutating) → Schema validation → Admission (validating) → etcd
```

**Admission Controllers** = "ostatnie słowo" przed zapisem do etcd. Mogą:
- **Mutate** — modyfikować obiekt (np. inject sidecar — Istio robi to)
- **Validate** — odrzucić obiekt (np. wymaga label, sprawdza policy)

Trzy podejścia:
1. **Built-in** (zaszyte w apiserver) — ResourceQuota, PodSecurity (PSA — D4/02), LimitRanger, ServiceAccount, …
2. **Webhooks** (`ValidatingWebhookConfiguration` / `MutatingWebhookConfiguration`) — deleguj decyzję do zewnętrznego HTTP serwisu (OPA/Gatekeeper — D4/09, Kyverno, Vault Webhook)
3. **ValidatingAdmissionPolicy + CEL** (K8s 1.30+ stable) — policy in-cluster bez external webhook (lekkie, fast)

## Prereqs
- K3d/Kind cluster

## Zadanie

1. Lista wbudowanych admission controllers (apiserver flag):
   ```bash
   kubectl get pod -n kube-system -l component=kube-apiserver -o yaml | grep enable-admission
   # --enable-admission-plugins=NodeRestriction,PodSecurity,...
   ```

2. Sprawdź zarejestrowane webhooks:
   ```bash
   kubectl get validatingwebhookconfiguration
   kubectl get mutatingwebhookconfiguration
   ```

3. Po zainstalowaniu Vault (D4/04) lub Gatekeeper (D4/09) — zobacz nowe webhooks.

4. **Praktyczne ćwiczenie webhook-based**: patrz **D4/09 OPA/Gatekeeper** dla pełnego przykładu z ConstraintTemplate + Constraint.

5. **Praktyczne ćwiczenie ValidatingAdmissionPolicy** (CEL, K8s 1.30+):
   ```yaml
   apiVersion: admissionregistration.k8s.io/v1
   kind: ValidatingAdmissionPolicy
   metadata: { name: require-replicas-min }
   spec:
     failurePolicy: Fail
     matchConstraints:
       resourceRules:
         - apiGroups: ["apps"]
           apiVersions: ["v1"]
           operations: ["CREATE", "UPDATE"]
           resources: ["deployments"]
     validations:
       - expression: "object.spec.replicas >= 2"
         message: "Deployment musi mieć min 2 repliki"
   ```

## Pytania kontrolne
1. Mutating przed Validating — czemu kolejność?
2. Webhook timeout = 10s default — co się stanie gdy webhook padnie?
3. ValidatingAdmissionPolicy (CEL) vs Gatekeeper (Rego) — kiedy które?
4. Jak debugować "moja policy odrzuca wszystko"? (Hint: dryrun + audit logs apiserver)

## Linki
- [Admission Controllers reference](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/)
- [Dynamic Admission Control (webhooks)](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/)
- [ValidatingAdmissionPolicy + CEL](https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy/)

## Worth checking
- [Kyverno](https://kyverno.io) — alternatywa OPA, YAML zamiast Rego
- [Open Policy Agent](https://www.openpolicyagent.org) — patrz D4/09
