# Solution — 07_trivy_k8s

## Spodziewany VulnerabilityReport

Dla obrazu `vulhub/log4j:2.8.1` (release 2017) Trivy znajdzie ~30 CVE Critical + ~110 High — Java 8 JRE + log4j 2.8.1 mają dekadę nienałożonych łatek:

```yaml
apiVersion: aquasecurity.github.io/v1alpha1
kind: VulnerabilityReport
metadata:
  name: replicaset-log4shell-vuln-xxxxxx-app
  namespace: default
report:
  summary:
    criticalCount: 32
    highCount: 114
    mediumCount: 169
    lowCount: 76
    unknownCount: 13
  vulnerabilities:
    - vulnerabilityID: CVE-2021-44228
      severity: CRITICAL
      title: "Apache Log4j 2: Remote code execution via JNDI lookup"
      score: 10
      installedVersion: 2.14.1
      fixedVersion: 2.15.0
      ...
```

## Odpowiedzi

### ignoreUnfixed
Filtruje CVE bez dostępnego fix'a. Trade-off:
- ✅ Zmniejsza szum — focus na to, co naprawialne
- ❌ Ukrywa realne CVE które nie mają patcha (mitigation często możliwa innymi metodami: NetworkPolicy, WAF, disable feature flag)

W produkcji: **dwa raporty** — pełny dla security team, filtered dla devs.

### Trivy Operator vs `trivy k8s`
- **Trivy Operator** (CRD-based, in-cluster) — ciągłe, automatyczne, integracja z Prometheus/Grafana, alertowanie
- **`trivy k8s`** (CLI) — ad-hoc, do CI/CD, nie wymaga instalacji w klastrze:
   ```bash
   trivy k8s --report all cluster
   trivy k8s --report all -n production deployment/api
   ```

Oba — komplementarne. CLI w pre-deploy gates, Operator w runtime monitoring.

### Częstotliwość skanu
Default 6h to dobry kompromis. Gdy klaster ma 1000+ Podów:
- skan 1 obrazu = ~5-30s
- 1000 obrazów co 6h = przeciętnie 1 skan/22s — node Trivy obciążony stale

Strategie:
- `--scanJobsConcurrentLimit=10` żeby nie zalać klastra
- `--scanJobTimeout=5m` żeby nie wisiał nieskończenie
- Skan rzadziej (24h) + `trivy k8s` raz dziennie z CI

### Action plan dla CRITICAL
Zalecana eskalacja:
1. **Detection**: VulnerabilityReport → Prometheus alert (`trivy_image_vulnerabilities{severity="Critical"} > 0`)
2. **Notification**: AlertManager → Slack/PagerDuty
3. **Action**:
   - Jeśli fixedVersion istnieje → automatic PR (Renovate/Dependabot bumps base image)
   - Jeśli nie ma fix → mitigation w klastrze (NetworkPolicy ograniczająca egress, czasowo wyłączyć feature)
   - Jeśli aktywnie eksploatowany w naturze → ROLLBACK + incident response
4. **Audit**: log decyzji (zaakceptowane ryzyko vs naprawione) — required by SOC2/ISO27001

NIE rekomendowane: auto-rollback na sam VulnerabilityReport. Może wywołać outage z powodu MEDIUM CVE.

## Walidacja

```bash
# Wszystkie CVE Critical w klastrze
kubectl get vulnerabilityreports -A -o json | \
  jq '.items[] | select(.report.summary.criticalCount > 0) | {ns: .metadata.namespace, name: .metadata.name, crit: .report.summary.criticalCount}'

# Top 10 CVE per liczba wystąpień w klastrze
kubectl get vulnerabilityreports -A -o json | \
  jq -r '.items[].report.vulnerabilities[].vulnerabilityID' | \
  sort | uniq -c | sort -rn | head -10
```

## Troubleshooting

### `No resources found` mimo że scany kończą się sukcesem

Operator nie potrafi sparsować statusu nowoczesnego K8s Job:
```bash
kubectl logs -n trivy-system deployment/trivy-operator | grep -i "unrecognized scan job condition"
# error: unrecognized scan job condition: SuccessCriteriaMet
```
**Fix:** chart `0.32.1+` (operator binary 0.30.1+). Starsze (≤0.20.x → binary 0.18.x) nie znają warunku `SuccessCriteriaMet` dodanego w K8s 1.31. Scan kończy się sukcesem, ale reconcile fails → `VulnerabilityReport` nigdy nie zostaje utworzony.

### Scan jobs `OOMKilled`

```bash
kubectl get pods -n trivy-system | grep OOMKilled
```
Default `trivy.resources.limits.memory=500M`. Dla obrazów Java/Spring/.NET/distroless+JVM (np. `vulhub/log4j`) Trivy potrzebuje rozpakować i zindeksować >500MB warstw. Bumpuj do `1G` w install command. Dla bardzo dużych obrazów → `2G`.

### Operator w `CrashLoopBackOff` z `liveness probe failed`

```
Warning Unhealthy ... Liveness probe failed: Get "http://...:9090/healthz/": dial tcp ...:9090: connect: connection refused
```
Operator startuje cache-sync wszystkich K8s resources (ClusterRoles, RBAC, DaemonSets, …). Na klastrze z dużą liczbą obiektów (Falco DS + Gatekeeper + vault + csi-driver = setki) trwa to 60-120s. Default container nie ma `requests/limits` = BestEffort → kernel ubija przy memory pressure, a liveness probe odpala po 100s. **Fix:** explicit `operator.resources` (Burstable QoS, ~256-512Mi) w install command.

## Cross-link
- D1/04 — Trivy CLI (build time)
- D5/04 — Grafana dashboard 17813 dla Trivy Operator metrics
- prezentacja D4 — supply chain (jak Cosign chroni przed podstawieniem obrazu *po* skanie)
