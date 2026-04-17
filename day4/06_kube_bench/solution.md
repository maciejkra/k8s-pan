# Solution — 06_kube_bench

## Spodziewany output (skrót)

```
[INFO] 1 Master Node Security Configuration
[INFO] 1.1 Master Node Configuration Files
[PASS] 1.1.1 Ensure that the API server pod specification file permissions are set to 600 ...
[FAIL] 1.1.12 Ensure that the etcd data directory ownership is set to etcd:etcd ...
...
[INFO] 5 Kubernetes Policies
[FAIL] 5.1.5 Ensure that default service accounts are not actively used (Manual)
[WARN] 5.1.6 Ensure that Service Account Tokens are only mounted where necessary (Manual)
[FAIL] 5.2.5 Minimize the admission of containers wishing to share the host network namespace
...
== Summary ==
54 checks PASS
12 checks FAIL
22 checks WARN
3 checks INFO
```

## Odpowiedzi

### Scored vs not scored
- **Scored** = automatycznie weryfikowalne, liczy się do zgodności (FAIL = niezgodność).
- **Not scored** = wymaga manual review (WARN = sprawdź ręcznie).

Standardy compliance (PCI DSS, SOC2) zazwyczaj wymagają tylko scored checks. Ale dobre praktyki = adresować również warn.

### Manual checks
Np. "Ensure RBAC roles are reviewed quarterly" — kube-bench nie wie, czy ktoś ostatnio reviewował RBAC. Wykonanie:
1. `kubectl get clusterroles,roles -A`
2. Eksport do CSV
3. Spotkanie z owner zespołów raz na kwartał
4. Dokument w Confluence/Notion z datą

### Profile per provider
EKS/GKE/AKS managed control plane — control-plane sekcje (1.x) nie mają sensu, bo Amazon zarządza apiserverem. CIS opublikowała osobne benchmarki "EKS 1.5.0", "GKE 1.6.0", "AKS 1.5.0" — sprawdzają tylko to, co user kontroluje (worker nody, RBAC, NetworkPolicy, audit logs).

```bash
kube-bench --benchmark eks-1.5.0      # tylko worker + policies
```

### CI/CD integration
Argo CD pre-sync hook:
```yaml
metadata:
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
```
Job wykonuje kube-bench. Jeśli FAIL > threshold → sync zablokowany.

Alternatywnie: Tekton pipeline / GitHub Actions z `gh api kubectl logs ...` + test na exit code.

## Walidacja remediation 5.1.5

```bash
kubectl logs job/kube-bench | grep -A 3 "5.1.5"
# Przed remediation:
# [FAIL] 5.1.5 Ensure that default service accounts are not actively used

kubectl delete job/kube-bench
kubectl apply -f remediation-5.1.5.yaml
kubectl apply -f kube-bench-job.yaml
kubectl wait --for=condition=complete job/kube-bench --timeout=2m
kubectl logs job/kube-bench | grep -A 3 "5.1.5"
# [PASS] 5.1.5 ...
```

## K3d/K3s caveat

K3s ma alternatywną topologię (jeden binary `k3s server`, brak osobnych kontenerów apiserver/scheduler/controller-manager). Część testów 1.x i 2.x nie zadziała — kube-bench wypisze:
```
[INFO] No tests applied
```

W produkcji szkolenia rekomendowane: pokaz na **kind** (waniliowy K8s) zamiast K3d, jeśli mają być pełne wyniki sekcji 1-2. Sekcja 5 (Policies) działa wszędzie tak samo.
