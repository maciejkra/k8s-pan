# 07 — Trivy w klastrze: Trivy Operator

## Cel
Zainstalować Trivy Operator w klastrze, włączyć ciągłe skanowanie obrazów uruchomionych Podów, zinterpretować VulnerabilityReport.

## Kontekst
W D1/04 skanowaliśmy obrazy **przed** deployem (CI). To nie wystarczy:
- Nowe CVE w bibliotece pojawiają się **po** zbudowaniu obrazu (CVE w log4j wykryto miesiące po release).
- Obraz w klastrze może żyć tygodniami / miesiącami.

[Trivy Operator](https://github.com/aquasecurity/trivy-operator) automatyzuje:
- skanuje obrazy wszystkich uruchomionych Podów
- regularnie re-skanuje (default: 6h)
- tworzy CRD-y w klastrze: `VulnerabilityReport`, `ConfigAuditReport`, `ExposedSecretReport`, `RbacAssessmentReport`
- raporty są query-walne przez `kubectl` i Grafanę

## Prereqs
- K3d cluster

## Zadanie

1. Instalacja przez Helm:
   ```bash
   helm repo add aqua https://aquasecurity.github.io/helm-charts
   helm repo update
   helm install trivy-operator aqua/trivy-operator \
     -n trivy-system --create-namespace \
     --set="trivy.ignoreUnfixed=true" \
     --version 0.20.6
   kubectl wait --for=condition=Available -n trivy-system deployment/trivy-operator --timeout=2m
   ```

2. Wdroż celowo podatną aplikację:
   ```bash
   kubectl apply -f vulnerable-app.yaml
   ```

3. Czekaj aż Trivy Operator zeskanuje (1-3 min):
   ```bash
   kubectl get vulnerabilityreports -A -w
   ```

4. Zobacz raport:
   ```bash
   kubectl get vulnerabilityreports -A
   kubectl describe vulnerabilityreport -A | head -50
   ```

5. Wszystkie raporty per deployment:
   ```bash
   kubectl get vulnerabilityreports -A -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.report.summary.criticalCount}{" CRIT, "}{.report.summary.highCount}{" HIGH"}{"\n"}{end}'
   ```

6. Inne raporty:
   ```bash
   kubectl get configauditreports -A
   kubectl get rbacassessmentreports -A
   kubectl get exposedsecretreports -A
   ```

7. **Bonus** — integracja z Prometheus:
   ```bash
   kubectl get servicemonitor -n trivy-system
   # Trivy Operator eksportuje metryki: trivy_image_vulnerabilities, trivy_resource_configaudits
   # Można je zwizualizować w Grafanie (D5/04)
   ```


## Linki
- [Trivy Operator docs](https://aquasecurity.github.io/trivy-operator/)
- [Grafana dashboard ID 17813](https://grafana.com/grafana/dashboards/17813-trivy-operator-vulnerability-reports/)
