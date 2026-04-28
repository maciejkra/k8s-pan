# Zadanie

## Część 1 — Install Trivy Operator

```bash
helm repo add aqua https://aquasecurity.github.io/helm-charts
helm repo update

helm install trivy-operator aqua/trivy-operator \
  -n trivy-system --create-namespace \
  --set="trivy.ignoreUnfixed=true" \
  --set="trivy.resources.requests.memory=512M" \
  --set="trivy.resources.limits.memory=1G" \
  --set="operator.resources.requests.memory=256Mi" \
  --set="operator.resources.limits.memory=512Mi" \
  --set="operator.builtInTrivyServer=false" \
  --version 0.32.1

kubectl wait --for=condition=Available -n trivy-system deployment/trivy-operator --timeout=3m
```

Sprawdź że operator startuje bez restartów:
```bash
kubectl get pods -n trivy-system
# trivy-operator-xxx 1/1 Running 0 (RESTARTS=0)
```

## Część 2 — Wdroż celowo podatną aplikację

```bash
kubectl apply -f vulnerable-app.yaml
kubectl get pods -l app=log4shell
```

`vulhub/log4j:2.8.1` to obraz Java z 2017 — log4j 2.14.1 + JRE 8 z dziesiątkami nienałożonych łatek.

## Część 3 — Czekaj na pierwsze raporty

Pierwszy run pobiera Trivy DB (~150MB) — 2-4 min. Kolejne re-skany co 6h (default).

```bash
kubectl get vulnerabilityreports -A -w
# co kilkadziesiąt sekund pojawiają się kolejne raporty per kontener
```

Przerwij `Ctrl+C` gdy zobaczysz `replicaset-log4shell-vuln-...`.

## Część 4 — Interpretacja VulnerabilityReport

```bash
# Lista wszystkich
kubectl get vulnerabilityreports -A
```

Liczba CVE Critical/High per kontener:
```bash
kubectl get vulnerabilityreports -A -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.report.summary.criticalCount}{" CRIT, "}{.report.summary.highCount}{" HIGH"}{"\n"}{end}'
```

Spodziewane dla `log4shell-vuln`: ~30 CRIT, ~110 HIGH (Java 8 + log4j 2.14.1).

Pełny dump jednego raportu:
```bash
kubectl get vulnerabilityreport -A -o yaml | head -120
# Zobaczysz CVE-2021-44228 (Log4Shell), CVE-2021-45046 itp.
```

## Część 5 — Inne raporty Trivy

Trivy Operator generuje 4 typy raportów:
```bash
kubectl get vulnerabilityreports -A     # CVE w obrazach
kubectl get configauditreports -A       # K8s misconfigs (np. runAsRoot=true)
kubectl get rbacassessmentreports -A    # nadmiarowe uprawnienia w RBAC
kubectl get exposedsecretreports -A     # plaintext secrets w obrazach
```

Spróbuj znaleźć:
- ConfigAuditReport ze "**critical**" failed check (np. SA auto-mount, hostPID, …).
- RbacAssessmentReport z `KSV* high` — klasyczne `cluster-admin` bindings.

## Część 6 — Query CVE przez jq (real-world workflow)

Wszystkie pody z critical CVE:
```bash
kubectl get vulnerabilityreports -A -o json | \
  jq -r '.items[] | select(.report.summary.criticalCount > 0) | "\(.metadata.namespace)/\(.metadata.name): \(.report.summary.criticalCount) CRIT"'
```

Top 10 najczęstszych CVE w klastrze:
```bash
kubectl get vulnerabilityreports -A -o json | \
  jq -r '.items[].report.vulnerabilities[].vulnerabilityID' | \
  sort | uniq -c | sort -rn | head -10
```

## Część 7 — Bonus: Prometheus + Grafana

```bash
# Trivy Operator eksportuje metryki Prometheus
kubectl get servicemonitor -n trivy-system
# trivy_image_vulnerabilities{severity="Critical"}
# trivy_resource_configaudits
```

W D5/04 importujemy Grafana dashboard 17813 — wizualizacja CVE per workload.

## Część 8 — Cleanup

```bash
helm uninstall trivy-operator -n trivy-system
kubectl delete -f vulnerable-app.yaml
kubectl delete crd $(kubectl get crd -o name | grep aquasecurity.github.io)
kubectl delete ns trivy-system
```

## Pytania

1. **`ignoreUnfixed`** — co filtruje? Trade-off: szum vs ukryte CVE bez patcha (mitigation możliwa innymi metodami: NetworkPolicy, WAF, feature flag off).
2. **Trivy Operator vs `trivy k8s` CLI** — kiedy które? (Hint: Operator = continuous in-cluster; CLI = ad-hoc, CI/CD pre-deploy gates.)
3. **Częstotliwość skanu** (default 6h) — co zmienić dla klastra z 1000+ Podów? (Hint: `scanJobsConcurrentLimit`, `scanJobTimeout`, rzadszy harmonogram.)
4. **CVE Critical action plan** — Detection → Notification → Action → Audit. Co automatyzować, co decyzja human-in-the-loop?
5. **Dlaczego CI scan nie wystarczy?** Nowe CVE pojawiają się **po** zbudowaniu obrazu — log4shell odkryto miesiące po release log4j 2.14.
