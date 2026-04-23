# Zadanie

## Część 1 — Setup namespace'y

```bash
kubectl apply -f ns.yaml
kubectl get ns psa-baseline psa-restricted --show-labels
# Zobacz label pod-security.kubernetes.io/*
```

## Część 2 — Baseline = nginx root PRZECHODZI (z warningiem)

```bash
kubectl apply -f deployment-baseline.yaml
# Spodziewane: warning w output:
#   Warning: would violate PodSecurity "restricted:latest": runAsNonRoot ...
#   deployment.apps/myapp created

# Ale Pod Running
kubectl wait --for=condition=ready pod -l app=myapp -n psa-baseline --timeout=30s
kubectl get pods -n psa-baseline
```

Dlaczego? `enforce: baseline` pozwala na root (baseline blokuje tylko privileged/hostPath/hostNet). `warn: restricted` wyświetla ostrzeżenie ale nie blokuje.

## Część 3 — Restricted = nginx root BLOKOWANY (negative test)

```bash
kubectl apply -f bad-pod-restricted.yaml
# Spodziewane (NATYCHMIAST — Pod NIE jest tworzony):
#   Error from server (Forbidden): error when creating "bad-pod-restricted.yaml":
#   pods "bad-pod" is forbidden: violates PodSecurity "restricted:latest":
#   allowPrivilegeEscalation != false (container "nginx" must set securityContext.allowPrivilegeEscalation=false),
#   unrestricted capabilities (container "nginx" must set securityContext.capabilities.drop=["ALL"]),
#   runAsNonRoot != true (pod or container "nginx" must set securityContext.runAsNonRoot=true),
#   seccompProfile (pod or container "nginx" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")

kubectl get pod bad-pod -n psa-restricted
# Error from server (NotFound): pods "bad-pod" not found
```

**To jest prawdziwy PSA w akcji.** Admission odrzucił Pod **zanim** został zapisany do etcd.

## Część 4 — Hardened Pod PRZECHODZI w restricted

```bash
kubectl apply -f hardened-pod-restricted.yaml
kubectl wait --for=condition=ready pod/hardened-pod -n psa-restricted --timeout=30s
# OK — pełen securityContext spełnia restricted
```

## Część 5 — Controller-level trap

Najciekawsza lekcja: Deployment "przechodzi", Pody NIE startują.

```bash
kubectl apply -f deployment-controller-trap.yaml
# Spodziewane: "deployment.apps/trap created" + warnings
# Uwaga: Deployment SAM nie jest Podem, admission dla Deployment przechodzi.

# Zobacz stan:
kubectl get deployment -n psa-restricted trap
# READY   UP-TO-DATE   AVAILABLE
# 0/3     0            0

# ReplicaSet:
kubectl get rs -n psa-restricted -l app=trap
# DESIRED   CURRENT   READY
# 3         0         0

# Events na ReplicaSet pokazują prawdę:
kubectl describe rs -n psa-restricted -l app=trap | grep -A 5 "Events"
# Events:
#   Warning  FailedCreate  replicaset-controller
#     Error creating: pods "trap-xxx-yyy" is forbidden: violates PodSecurity "restricted:latest"...
```

**Morał**: `kubectl apply` na Deployment zwróci "created", student myśli że wszystko OK. Dopiero `kubectl get pods` / `kubectl describe rs` pokazuje pętlę. W produkcji: alerts na `KubePodNotReady` + CI/CD validation.

## Część 6 — Audit log (bonus)

PSA audit level pisze do K8s audit log (jeśli klaster ma audit policy D5/03):
```bash
# Zakładając że audit policy jest włączone:
grep "pod-security.kubernetes.io" /var/log/kubernetes/audit.log | tail -5
```

Na K3s/K3d audit nie jest domyślnie włączone — patrz D5/03.

## Część 7 — Cleanup

```bash
kubectl delete ns psa-baseline psa-restricted
```

## Pytania

1. **PSA vs PSP** — dlaczego PSP został deprecated? (Hint: prostota, ograniczone możliwości, policy-as-manifest vs policy-as-RBAC.)
2. **Dlaczego `pod-security.kubernetes.io/enforce-version: latest`** vs konkretna wersja? (Hint: backward compat przy upgrade K8s.)
3. **Controller-level trap** — jak zapobiec ze strony CI/CD? (Hint: `kubectl apply --dry-run=server --validate` + `kubectl wait`.)
4. **PSA + Vault injector (D4/04)** — czy Vault Agent Injector Pod wstrzyknięty do poda w `enforce: restricted` zadziała? Co trzeba dostroić?
5. **Bonus**: PSA zawsze ma jakiś `enforce`, nawet bez labelów — jaki jest default i w którym NS? (Hint: `kube-system` ma `privileged` domyślnie.)
