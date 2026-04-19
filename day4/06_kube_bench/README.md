# 06 — kube-bench: audyt CIS

## Cel
Przeprowadzić audyt klastra K8s wg CIS Kubernetes Benchmark, zinterpretować wyniki i naprawić wybrany failed check.

## Kontekst
[CIS (Center for Internet Security) Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes) to ~150 best practices security dla klastra K8s, podzielone na sekcje:
- 1. Control Plane Components (kube-apiserver, etcd, scheduler, controller-manager)
- 2. etcd
- 3. Control Plane Configuration
- 4. Worker Nodes (kubelet, config files)
- 5. Policies (RBAC, Pod Security, Network Policies)

[kube-bench](https://github.com/aquasecurity/kube-bench) automatyzuje audit — czyta config files na nodach, sprawdza flagi procesów, raportuje PASS/WARN/FAIL.

W produkcji: kube-bench w cron Jobie + raporty do Grafana/Splunk/SIEM.

## Prereqs
- K3d cluster (uwaga: **K3d/K3s mają trochę inną konfigurację niż waniliowy K8s** — niektóre testy będą niedostępne, to OK do nauki)

## Zadanie

1. Uruchom kube-bench jako Job:
   ```bash
   kubectl apply -f kube-bench-job.yaml
   kubectl wait --for=condition=complete job/kube-bench --timeout=2m
   kubectl logs job/kube-bench | head -100
   ```

2. Pobierz pełny raport:
   ```bash
   kubectl logs job/kube-bench > kube-bench-report.txt
   wc -l kube-bench-report.txt
   ```

3. Filtruj po WARN/FAIL:
   ```bash
   grep -E "^\[(WARN|FAIL)\]" kube-bench-report.txt | head -20
   ```

4. Przeanalizuj jeden konkretny FAIL — np. **5.1.5** "Ensure that default service accounts are not actively used":
   ```bash
   grep -A 5 "5.1.5" kube-bench-report.txt
   ```
   Zobacz co kube-bench rekomenduje (`Remediation:`).

5. Zaaplikuj remediation:
   ```bash
   kubectl apply -f remediation-5.1.5.yaml      # patchuje default SA: automountServiceAccountToken: false
   ```

6. Uruchom kube-bench ponownie i porównaj:
   ```bash
   kubectl delete job/kube-bench
   kubectl apply -f kube-bench-job.yaml
   kubectl wait --for=condition=complete job/kube-bench --timeout=2m
   kubectl logs job/kube-bench | grep "5.1.5"
   ```

7. **Bonus** — uruchom w trybie node-specific (sprawdza kubelet config):
   ```bash
   kubectl apply -f kube-bench-node.yaml
   ```


## Linki
- [kube-bench docs](https://github.com/aquasecurity/kube-bench)
- [CIS K8s Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [Trivy ma także built-in audit CIS — D4/07](https://aquasecurity.github.io/trivy/latest/docs/compliance/compliance/)
