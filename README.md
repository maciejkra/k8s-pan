# k8s-training-2026

5-dniowe szkolenie Docker + Kubernetes. Materiały bazują na [maciejkra/k8s-full](https://github.com/maciejkra/k8s-full), rozszerzone o security tools, Gateway API, AI/GPU.

**Komponenty:**
- 📁 [`day1/` … `day5/`](#agenda--katalogi) — ćwiczenia praktyczne (manifesty + README + task + solution)
- 🛠️ [`setup-cluster.sh`](./setup-cluster.sh) — bootstrap lokalnego K3d klastra (skrót dla testowania)
- 📋 [`SETUP.md`](./SETUP.md) — instalacja narzędzi + dual-runtime (K3s/Kind) setup
- 📄 [`docs/presentation-errata.md`](./docs/presentation-errata.md) — poprawki dla slajdów w `k8s-training-2026.pdf`

## Quick start

Dla szybkiego demo — K3d (K3s w Dockerze):
```bash
./setup-cluster.sh        # K3d cluster + Envoy Gateway + cert-manager + metrics-server
kubectl get nodes
```

Dla **K3s** / **Kind** (produkcyjnie lepsze warianty) — patrz `SETUP.md` sekcja "Runtime compatibility".

## Runtime compatibility

Uczestnicy mogą używać **K3s**, **Kind** lub **K3d** (K3s w Dockerze). Każde ćwiczenie od day2/07 jest przygotowane pod wszystkie trzy. Główne różnice:

| Runtime | LoadBalancer | CNI default | NetworkPolicy | Metrics server |
|---|---|---|---|---|
| **K3s / K3d** | Klipper built-in | Flannel | **NIE wspiera domyślnie** (potrzebny Cilium) | wbudowany (od 1.23+) |
| **Kind** | wymaga MetalLB / cloud-provider-kind | kindnet | ingress od v0.20, egress od v0.26 | wymaga `--kubelet-insecure-tls` |

Matryca — które ćwiczenia wymagają szczególnego setupu:
- **D3/08 NetworkPolicy** — K3s wymaga switch CNI na Cilium/Calico; Kind z kindnet >= v0.26.
- **D5/02 Monitoring** — kind.yaml zawiera `bind-address: 0.0.0.0` dla metrics scraping.
- **D5/03 kubeadm walkthrough** — NIE działa na K3d/Kind/K3s (wymaga 6 VM); Multipass / DigitalOcean / Vagrant.
- **D5/04 fake-gpu-operator** — działa na wszystkich (kwok-based).

## Mapa katalogów

### Dzień 1 — Docker + K8s podstawy

| # | Sekcja | Katalog |
|---|---|---|
| 01 | Pierwszy obraz nginx | `day1/01_nginx_image` |
| 02 | Multi-stage Go binary (secure image) | `day1/02_secure_image` |
| 03 | K8s — Kind cluster + kubectl | `day1/03_k8s` |
| 04 | Pod | `day1/04_pod` |
| 05 | Inspekcja node | `day1/05_node` |
| 06 | Labels i selectors | `day1/06_labels` |
| 07 | Service (ClusterIP/NodePort/External) | `day1/07_service` |
| 08 | Probes (liveness/readiness/startup) | `day1/08_probes` |
| 09 | ReplicaSet | `day1/09_replica_set` |
| 10 | Deployment + rolling update + rollback | `day1/10_deployment` |
| 11 | Namespaces | `day1/11_namespace` |
| 12 | Multi-container Pod (sidecar pattern) | `day1/12_multi_container_pod` |

### Dzień 2 — Workloady, AuthN/AuthZ, Gateway API

| # | Sekcja | Katalog |
|---|---|---|
| 01 | Jobs (Parallel Completion + Queue) | `day2/01_jobs` |
| 02 | CronJob | `day2/02_cronjob` |
| 03 | Storage: emptyDir, hostPath, PV/PVC, StorageClass | `day2/03_volume` |
| 04 | Annotations | `day2/04_annotations` |
| 05 | ConfigMap (env + mount, auto-refresh) | `day2/05_configmap` |
| 06 | AuthN/AuthZ: SA Token, x509 cert, OIDC, RBAC | `day2/06_auth` |
| 07 | **Gateway API + cert-manager + Let's Encrypt** | `day2/07_gateway_api` |
| 08 | StatefulSet | `day2/08_statefulsets` |
| 09 | DaemonSet (node-exporter realistic use case) | `day2/09_daemonsets` |
| 10 | Secrets (generic, docker-registry, tls) + consumer Pod | `day2/10_secrets` |

### Dzień 3 — Scheduling, autoscaling, deployment

| # | Sekcja | Katalog |
|---|---|---|
| 01 | Init containers + full Pod lifecycle | `day3/01_init_containers` |
| 02 | QoS (pod_limits, limitrange, resource_quota) | `day3/02_QoS` |
| 03 | Metrics Server (K3s vs Kind) | `day3/03_metrics_server` |
| 04 | HPA + `spec.behavior` policies | `day3/04_HPA` |
| 05 | **Canary (Gateway API weightedBackendRefs)** + porównanie 6 strategii | `day3/05_Canary` |
| 06 | Scheduling: affinity + taints + TSC | `day3/06_scheduling_rules` |
| 07 | PriorityClass + preemption | `day3/07_pod_priority` |
| 08 | Network Policies (**wymaga CNI z policy support**) | `day3/08_network_policy` |
| 09 | Node maintenance (cordon, drain, PDB) | `day3/09_node_maintenance` |

### Dzień 4 — Security: pełen stack

| # | Sekcja | Katalog |
|---|---|---|
| 01 | Debug Pod (ephemeral containers, `kubectl debug`) | `day4/01_debug_pod` |
| 02 | Pod Security Admission — **negative test + controller-level trap** | `day4/02_psa_security` |
| 03 | Admission Controllers + ValidatingAdmissionPolicy (CEL) | `day4/03_Admission_Controllers` |
| 04 | HashiCorp Vault (3 wzorce) + sekcja ESO | `day4/04_vault` |
| 05 | SecurityContext (non-root, capabilities, seccomp) | `day4/05_security_context` |
| 06 | kube-bench (CIS audit) | `day4/06_kube_bench` |
| 07 | Trivy Operator (in-cluster CVE scan) | `day4/07_trivy_k8s` |
| 08 | Falco (runtime detection, custom rules via helm values) | `day4/08_falco` |
| 09 | OPA / Gatekeeper (validate + mutate) | `day4/09_opa_gatekeeper` |

### Dzień 5 — Helm, monitoring, kubeadm, AI/GPU

| # | Sekcja | Katalog |
|---|---|---|
| 01 | Helm (install + OCI + own chart) | `day5/01_helm` |
| 02 | Monitoring (Prometheus + Grafana + Loki + custom Rule) | `day5/02_monitoring_alerting` |
| 03 | **kubeadm walkthrough (3CP+3W+kube-vip static pod+Cilium)** | `day5/03_install` |
| 04 | AI/GPU na K8s (fake-gpu-operator, MIG) | `day5/04_ai_gpu` |

---

## Tematy "tylko prezentacja" (bez ćwiczeń)

Te tematy są w prezentacji jako slajdy, bez osobnych warsztatów (ze względu na czas, infra, lub charakter):

- **Optymalizacja Dockerfile** (D1) — pokazane w demo `02_secure_image`
- **Trivy scan obrazów** (D1) — demo na żywo `trivy image`
- **Cosign + SBOM** (D4) — "przegląd" wg agendy
- **Service Mesh** (D4) — Istio/Linkerd/Cilium porównanie
- **Pentesty K8s** (D4) — kube-hunter, peirates, MITRE ATT&CK
- **Supply chain SLSA** (D4) — cross-link D1 (Cosign) + D4 (admission)
- **Kueue** (D5) — job queueing dla AI/ML
- **DCGM Exporter** (D5) — metryki GPU
- **GPU production practices** (D5) — node pools, spot, Karpenter
- **Narzędzia dev** (D5) — kubectx, kubens, k9s, Lens, Telepresence

---

## Format ćwiczenia

```
day<N>/<NN_topic>/
├── README.md     # cel · kontekst · prereqs · pliki · linki
├── task.md       # kroki do wykonania + pytania kontrolne
├── *.yaml/*.sh   # manifesty / skrypty
└── solution.md   # odpowiedzi + walidacja + troubleshooting + cross-link
```

---

## Tips

### kubectl autocomplete
- [Linux](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#enable-shell-autocompletion)
- [Windows](https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/#enable-shell-autocompletion)
- [macOS](https://kubernetes.io/docs/tasks/tools/install-kubectl-macos/)
