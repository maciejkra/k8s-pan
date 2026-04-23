# Zadanie

## Część 1 — Uruchom kube-bench jako Job

```bash
kubectl apply -f kube-bench-job.yaml
kubectl wait --for=condition=complete job/kube-bench --timeout=3m
```

Dla **K3s/K3d**: edytuj `kube-bench-job.yaml` żeby użyć `--benchmark k3s-cis-1.24`:
```bash
kubectl patch job kube-bench --type=json -p='[
  {"op":"replace","path":"/spec/template/spec/containers/0/command","value":["kube-bench","--benchmark","k3s-cis-1.24"]}
]'
```

## Część 2 — Przeanalizuj wyniki

```bash
kubectl logs job/kube-bench > kube-bench-report.txt
echo "Linie: $(wc -l < kube-bench-report.txt)"
grep -c "\[PASS\]" kube-bench-report.txt
grep -c "\[FAIL\]" kube-bench-report.txt
grep -c "\[WARN\]" kube-bench-report.txt

# Pokaż wszystkie FAIL
grep -E "^\[FAIL\]" kube-bench-report.txt
```

## Część 3 — Napraw 5.1.5 (default SA nie używany)

1. Zobacz szczegóły testu:
   ```bash
   grep -A 6 "5.1.5" kube-bench-report.txt
   ```
   Typowy output:
   ```
   [FAIL] 5.1.5 Ensure that default service accounts are not actively used
       Remediation: Create explicit service accounts wherever a Kubernetes workload requires
   ```

2. Zaaplikuj remediation:
   ```bash
   kubectl apply -f remediation-5.1.5.yaml
   # Patchuje default SA w default, kube-system, kube-public:
   #   automountServiceAccountToken: false
   ```

3. Re-run kube-bench:
   ```bash
   kubectl delete job/kube-bench
   kubectl apply -f kube-bench-job.yaml
   kubectl wait --for=condition=complete job/kube-bench --timeout=3m
   kubectl logs job/kube-bench | grep -A 1 "5.1.5"
   ```

Spodziewane: `[PASS] 5.1.5`.

## Część 4 — K3s/K3d caveat

Dla K3s / K3d testy sekcji 1-2 (Control Plane Components) nie działają — etcd jest wbudowany w k3s binary, nie ma osobnych plików `/var/lib/etcd/*` ani `/etc/kubernetes/manifests/kube-apiserver.yaml`.

Zobacz:
```bash
kubectl logs job/kube-bench | head -10
# [INFO] No tests applied (albo "1.x.x No such file/directory")
```

Rozwiązanie: **użyj profile `k3s-cis-1.24`** który wie o K3s architekturze (część 1.x pominięta, 5.x enforcement jak wanilia).

Alternatywnie: odpal kube-bench na **Kind** który jest waniliowym K8s.

## Część 5 — Per-provider profiles

```bash
# EKS — brak testów 1-3 (AWS zarządza CP), tylko worker + policies (4-5)
kubectl patch job kube-bench --type=json -p='[
  {"op":"replace","path":"/spec/template/spec/containers/0/command","value":["kube-bench","--benchmark","eks-1.5.0"]}
]'

# GKE, AKS, RKE2 — analogiczne profile
# kube-bench --benchmark gke-1.6.0
# kube-bench --benchmark aks-1.5.0
# kube-bench --benchmark rke2-cis-1.24
```

## Część 6 — CI/CD integration (bonus)

Uruchom jako Argo CD pre-sync hook:
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: kube-bench-presync
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
```

Sync zablokowany jeśli FAIL > threshold (policy w Argo).

## Część 7 — Cleanup

```bash
kubectl delete job kube-bench
```

## Pytania

1. **Scored vs not-scored** — kiedy można ignorować warny (WARN)?
2. **Manual checks** — kube-bench oznacza niektóre testy jako "Manual". Jak je obsłużyć?
3. **Per-provider benchmarks** (EKS/GKE/AKS) — co jest pominięte vs waniliowy?
4. **K3s caveat** — dlaczego sekcja 1-2 nie działa? Co robić w produkcji (prawdziwy K8s nie K3s)?
5. **Bonus**: **Trivy compliance** (D4/07) ma własny CIS audit. Kiedy trivy, kiedy kube-bench?
