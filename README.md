# k8s-training-2026

5-dniowe szkolenie Docker + Kubernetes. Materiały bazują na [maciejkra/k8s-full](https://github.com/maciejkra/k8s-full), rozszerzone o security tools, Gateway API, AI/GPU.

**Komponenty:**
- 📁 [`day1/` … `day5/`](#agenda--katalogi) — ćwiczenia praktyczne (manifesty + README + solution)
- 🎤 [`presentation/dist/k8s-training-2026.pdf`](./presentation/dist/k8s-training-2026.pdf) — slajdy (76 stron, Marp). Build: `presentation/build.sh`
- 🛠️ [`setup-cluster.sh`](./setup-cluster.sh) — bootstrap lokalnego K3d klastra
- 📋 [`SETUP.md`](./SETUP.md) — instalacja narzędzi (kubectl, helm, k3d, trivy, cosign…)

## Quick start

```bash
./setup-cluster.sh        # K3d cluster + Envoy Gateway + cert-manager + metrics-server
kubectl get nodes
```

Pełna instalacja narzędzi (kubectl, helm, k3d, trivy, cosign, …) — patrz `SETUP.md`.

## Agenda → katalogi

### Dzień 1 — Docker

| Sekcja agendy | Katalog |
|---|---|
| Docker basics, obrazy | `day1/01_nginx_image`, `day1/02_secure_image` |
| Optymalizacja Dockerfile | `day1/03_dockerfile_optimization` |
| Skanowanie obrazów (Trivy) | `day1/04_image_scanning_trivy` |
| Podpisywanie obrazów (Cosign + SBOM) | `day1/05_image_signing_cosign` |
| Hardening obrazów | `day1/06_hardening` |
| K8s podstawy: Pod, Service, Deployment, Namespace, Probes | `day1/04_k8s` … `day1/12_namespace` |

### Dzień 2 — Workloady, sieci, auth

| Sekcja agendy | Katalog |
|---|---|
| Jobs / CronJobs | `day2/01_jobs`, `day2/02_cronjob` |
| Storage: Volumes, ConfigMaps, Secrets | `day2/03_volume`, `day2/05_configmap`, `day2/10_secrets` |
| Adnotacje | `day2/04_annotations` |
| AuthN/AuthZ: token, cert x509, OIDC, RBAC, ServiceAccount | `day2/06_auth` |
| Eksponowanie usług: Gateway API + cert-manager + Let's Encrypt | `day2/07_gateway_api` |
| StatefulSets, DaemonSets | `day2/08_statefulsets`, `day2/09_daemonsets` |

### Dzień 3 — Scheduling, autoscaling, deployment

| Sekcja agendy | Katalog |
|---|---|
| Init containers, lifecycle | `day3/01_init_containers` |
| QoS | `day3/02_QoS` |
| Metrics Server, HPA | `day3/03_metrics_server`, `day3/04_HPA` |
| Strategie wdrożeń (Canary) | `day3/05_Canary` |
| Scheduling: nodeSelector, affinity, taints/tolerations | `day3/06_scheduling_rules` |
| PriorityClass, preemption | `day3/07_pod_priority` |
| Network Policies | `day3/08_network_policy` |
| Node maintenance: cordon, drain, PDB | `day3/09_node_maintenance` |

### Dzień 4 — Security, admission, vault

| Sekcja agendy | Katalog |
|---|---|
| Debug / scratch pod | `day4/01_debug_pod` |
| Pod Security Admission | `day4/02_psa_security` |
| Admission Controllers | `day4/03_Admission_Controllers` |
| HashiCorp Vault | `day4/04_vault` |
| SecurityContext (runAsNonRoot, capabilities, seccomp) | `day4/05_security_context` |
| kube-bench (CIS audit) | `day4/06_kube_bench` |
| Trivy w klastrze (Trivy Operator) | `day4/07_trivy_k8s` |
| Falco (runtime security) | `day4/08_falco` |
| OPA / Gatekeeper | `day4/09_opa_gatekeeper` |
| Service Mesh — wprowadzenie | `day4/10_service_mesh_intro.md` |
| Pentesty klastra K8s | `day4/11_cluster_pentest_intro.md` |
| Supply chain (cross-link do D1) | `day4/12_supply_chain.md` |

### Dzień 5 — Helm, monitoring, kubeadm, AI/GPU

| Sekcja agendy | Katalog |
|---|---|
| Helm | `day5/02_helm` |
| Monitoring (Prometheus, Grafana, Loki) | `day5/04_monitoring_alerting` |
| Klaster od zera (kubeadm + Terraform) | `day5/06_install` |
| AI/GPU na K8s (fake-gpu-operator) | `day5/07_ai_gpu` |

---

## Struktura katalogu ćwiczeniowego

```
day<N>/<NN_topic>/
├── README.md     # cel, kontekst, prereqs, zadanie, pytania kontrolne, linki
├── *.yaml/*.sh   # manifesty / skrypty
└── solution.md   # rozwiązanie + wyjaśnienie
```

## Co zmieniło się względem upstream `maciejkra/k8s-full`

**Usunięte (poza agendą):**
- `day1/03_docker_compose_config` — Docker Compose nie pasuje do K8s-centric kursu
- `day2/07_ingress` — zastąpione `07_gateway_api` (przyszłościowy standard)
- `day3/07_crd` (bash-operator) — koncept CRD wprowadzimy przy Trivy/Vault/GPU operatorach
- `day5/01_kustomize` — Helm wystarczy
- `day5/03_TNSdemo` — demo Grafana Cloud, poza agendą
- `day5/05_dashboard` — alternatywy K8s Dashboard tylko na slajdach

**Dodane:**
- D1: 4 katalogi (Dockerfile optimization, Trivy scan, Cosign signing, hardening)
- D2: `07_gateway_api` (Envoy Gateway + cert-manager + Let's Encrypt)
- D3: `07_pod_priority`, `09_node_maintenance`
- D4: 5 katalogów ćwiczeń (security_context, kube_bench, trivy_k8s, falco, opa_gatekeeper) + 3 markdowny teoretyczne
- D5: `07_ai_gpu` (fake-gpu-operator, MIG, Kueue, DCGM, production practices)

**Tylko na slajdach (bez ćwiczeń):**
- Service Mesh (Istio/Linkerd/Cilium)
- Kyverno (alternatywa do OPA/Gatekeeper)
- K8s Dashboard alternatywy (Lens, Headlamp, Octant)
- Narzędzia developerskie (kubectx, kubens, k9s, Lens, Telepresence)

---

## Tips

### kubectl autocomplete
- [Linux](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#enable-shell-autocompletion)
- [Windows](https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/#enable-shell-autocompletion)
- [macOS](https://kubernetes.io/docs/tasks/tools/install-kubectl-macos/)
