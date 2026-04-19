# Agenda szczegółowa — 5 dni × 7h

Każdy dzień: **7 jednostek po 45 min** (godzina 9:00–16:00 z obiadem 12:30–13:15 i przerwami).

Proporcja teoria / praktyka: ~30% / ~70%.

Łącznie: **~30 ćwiczeń praktycznych** + ~15 modułów teoretycznych.

---

## Dzień 1 — Docker + K8s podstawy

| Blok | Godz. | Temat | Forma | Lab |
|------|-------|-------|-------|-----|
| 1 | 09:00–09:45 | Wstęp. Po co Docker? Kontener vs VM. Linux namespaces, cgroups, OverlayFS. containerd + runc. | Teoria + demo | — |
| — | 09:45–10:00 | Przerwa | | |
| 2 | 10:00–10:45 | Pierwszy obraz nginx — Dockerfile, build, run, port mapping | Warsztat | **D1/01** nginx_image |
| 3 | 11:00–11:45 | Optymalizacja Dockerfile, multi-stage, distroless, hardening, Trivy scan, Cosign sign | Teoria + demo | — |
| 4 | 11:45–12:30 | Multi-stage Go binary do scratch image | Warsztat | **D1/02** secure_image |
| — | 12:30–13:15 | **Obiad** | | |
| 5 | 13:15–14:00 | K8s — architektura. Kind cluster. kubectl + context. Pod jako najmniejsza jednostka | Teoria + warsztat | **D1/03** k8s + **D1/04** pod |
| 6 | 14:15–15:00 | Node, labels, namespace, services (ClusterIP/NodePort), DNS w klastrze | Warsztat | **D1/05** node, **D1/06** labels, **D1/07** service, **D1/11** namespace |
| 7 | 15:15–16:00 | Probes (liveness/readiness/startup), ReplicaSet, Deployment + rolling update | Warsztat | **D1/08** probes, **D1/09** replica_set, **D1/10** deployment |

**Bonus** (jeśli zostanie czas): **D1/12** multi_container_pod, **D1/13** kubectl_context

**Rezultat dnia:** Działający lokalny K3d klaster z deployment nginx + service NodePort + healthchecks. Zrozumienie pełnego flow Docker→K8s.

---

## Dzień 2 — Workloady, AuthN/AuthZ, Gateway API

| Blok | Godz. | Temat | Forma | Lab |
|------|-------|-------|-------|-----|
| 1 | 09:00–09:45 | Jobs / CronJobs — zadania jednorazowe i cykliczne. Wzorce paralelizmu. | Teoria + warsztat | **D2/01** jobs, **D2/02** cronjob |
| 2 | 10:00–10:45 | Storage: emptyDir, hostPath, PV, PVC, StorageClass. Reclaim policy. | Teoria + warsztat | **D2/03** volume |
| 3 | 11:00–11:45 | Annotations + ConfigMap (env vs mount, auto-refresh, Reloader) | Warsztat | **D2/04** annotations, **D2/05** configmap |
| 4 | 11:45–12:30 | AuthN/AuthZ: ServiceAccount tokens, x509 cert, OIDC. RBAC: Role, ClusterRole, Binding. | Warsztat | **D2/06** auth (token/cert/oidc) |
| — | 12:30–13:15 | **Obiad** | | |
| 5 | 13:15–14:00 | Gateway API + Envoy Gateway. cert-manager + Let's Encrypt. Migracja z Ingress. | Teoria + warsztat | **D2/07** gateway_api |
| 6 | 14:15–15:00 | StatefulSet — ordinal index, stable DNS, per-Pod PVC. Bazy w K8s — kiedy NIE. | Warsztat | **D2/08** statefulsets |
| 7 | 15:15–16:00 | DaemonSet (per-node). Secrets — generic, docker-registry, tls. Vault jako alternatywa. | Warsztat | **D2/09** daemonsets, **D2/10** secrets |

**Rezultat dnia:** Aplikacja wystawiona przez Gateway API z TLS od cert-manager, RBAC ograniczający dev do swojego namespace, Vault jako bezpieczne secret store.

---

## Dzień 3 — Scheduling, autoscaling, deployment

| Blok | Godz. | Temat | Forma | Lab |
|------|-------|-------|-------|-----|
| 1 | 09:00–09:45 | Init containers — pre-start setup, sequencing. Native sidecars (K8s 1.29+). | Teoria + warsztat | **D3/01** init_containers |
| 2 | 10:00–10:45 | QoS classes (Guaranteed/Burstable/BestEffort). LimitRange + ResourceQuota per namespace. | Warsztat | **D3/02** QoS (pod_limits, limitrange, resource_quota) |
| 3 | 11:00–11:45 | Metrics Server. HPA — autoscaling z load generatora. VPA, custom metrics. | Teoria + warsztat | **D3/03** metrics_server, **D3/04** HPA |
| 4 | 11:45–12:30 | Strategie wdrożeń (Recreate/Rolling/Blue-Green/Canary/A-B/Shadow). Argo Rollouts intro. | Teoria + warsztat | **D3/05** Canary |
| — | 12:30–13:15 | **Obiad** | | |
| 5 | 13:15–14:00 | Scheduling: nodeSelector, affinity (node + pod + anti), taints/tolerations, TSC. | Warsztat | **D3/06** scheduling_rules |
| 6 | 14:15–15:00 | Pod Priority + preemption. Built-in critical classes. | Warsztat | **D3/07** pod_priority |
| 7 | 15:15–16:00 | Network Policies (default-deny + selective). Node maintenance: cordon, drain, PDB. | Teoria + warsztat | **D3/08** network_policy, **D3/09** node_maintenance |

**Rezultat dnia:** Skalowanie HPA na load, canary release nginx 70/30, NetworkPolicy izolująca namespace, demo wywłaszczania PriorityClass + drain z PDB.

---

## Dzień 4 — Security: pełen stack

| Blok | Godz. | Temat | Forma | Lab |
|------|-------|-------|-------|-----|
| 1 | 09:00–09:45 | Debug Pod w distroless: kubectl debug ephemeral containers + copy-to. | Warsztat | **D4/01** debug_pod |
| 2 | 10:00–10:45 | Pod Security Admission — privileged/baseline/restricted × enforce/audit/warn. | Warsztat | **D4/02** psa_security |
| 3 | 11:00–11:45 | Admission Controllers — built-in, webhooks, ValidatingAdmissionPolicy + CEL (1.30+). | Teoria + warsztat | **D4/03** Admission_Controllers |
| 4 | 11:45–12:30 | HashiCorp Vault — CSI driver, env vars, agent injector. | Warsztat | **D4/04** vault |
| — | 12:30–13:15 | **Obiad** | | |
| 5 | 13:15–14:00 | SecurityContext — runAsNonRoot, capabilities drop, readOnlyRootFilesystem, seccomp. | Warsztat | **D4/05** security_context |
| 6 | 14:15–15:00 | kube-bench (CIS audit). Trivy Operator (in-cluster CVE scan). | Warsztat | **D4/06** kube_bench, **D4/07** trivy_k8s |
| 7 | 15:15–16:00 | Falco runtime detection (custom rules). OPA/Gatekeeper policy as code. Service Mesh / Pentesty / Supply chain — przegląd. | Teoria + warsztat | **D4/08** falco, **D4/09** opa_gatekeeper |

**Rezultat dnia:** Klaster z PSA restricted, Vault, Falco wykrywającym shell w produkcji, OPA policy wymuszającym `owner` label, Trivy raportującym CVE z log4shell demo.

---

## Dzień 5 — Helm, monitoring, kubeadm, AI/GPU

| Blok | Godz. | Temat | Forma | Lab |
|------|-------|-------|-------|-----|
| 1 | 09:00–09:45 | Helm — instalacja chart z repo + warsztat install/upgrade/rollback. | Teoria + warsztat | **D5/01** helm/01_install_chart |
| 2 | 10:00–10:45 | Tworzenie własnego chart (Python+Redis). Templates, values, helpers. | Warsztat | **D5/01** helm/03_own_chart |
| 3 | 11:00–11:45 | kube-prometheus-stack — Prometheus Operator, Grafana, AlertManager, ServiceMonitor. | Warsztat | **D5/02** monitoring_alerting |
| 4 | 11:45–12:30 | Loki + Fluent Bit — centralne logi, LogQL, integracja z Grafana. | Warsztat | **D5/02** monitoring_alerting (kontynuacja) |
| — | 12:30–13:15 | **Obiad** | | |
| 5 | 13:15–14:00 | kubeadm — produkcyjny klaster od zera (3 CP + 3 worker + kube-vip + Cilium). Walkthrough. | Teoria + demo | **D5/03** install |
| 6 | 14:15–15:00 | AI/GPU: NVIDIA Device Plugin, GPU Operator, fake-gpu-operator. Pod z `nvidia.com/gpu`. | Teoria + warsztat | **D5/04** ai_gpu/01-02 |
| 7 | 15:15–16:00 | Multi-GPU + MIG (Multi-Instance GPU). Kueue, DCGM, production practices — przegląd. | Warsztat + teoria | **D5/04** ai_gpu/03-04 |

**Rezultat dnia:** Działający stack monitoringu (Prometheus + Grafana + Loki + AlertManager), własny Helm chart z rollback, demo fake-gpu-operator z workloadem wymagającym `nvidia.com/gpu: 1` na CPU-only klastrze.

---

## Tematy "tylko prezentacja" (w slajdach, bez ćwiczeń)

Te tematy z agendy szkolenia są omawiane wyłącznie w prezentacji (ze względu na czas, wymagania infra, lub charakter materiału):

| Sekcja agendy | Slajdy | Powód |
|---|---|---|
| Optymalizacja Dockerfile | D1 | Pokazane jako transformacja w demo `secure_image` |
| Trivy scan obrazów | D1 | Demo na żywo `trivy image vuln-app` |
| Cosign + SBOM | D4 | "Przegląd" wg agendy — demo bez warsztatu |
| Service Mesh (Istio/Linkerd/Cilium) | D4 | Zbyt obszerne na osobne ćwiczenie — porównanie 3 mesh + kiedy używać |
| Pentesty K8s | D4 | Wymaga osobnego środowiska + autoryzacji — teoria + frameworki (MITRE, NSA/CISA) |
| Supply chain SLSA | D4 | Cross-link do D1 demo Cosign + admission policy w D4 OPA |
| Kueue (job queueing) | D5 | Zbyt obszerne — przegląd ResourceFlavor → ClusterQueue → Workload |
| DCGM Exporter + Prometheus queries | D5 | Wymaga prawdziwego GPU dla realnych metryk — przegląd metryk kluczowych |
| GPU production practices | D5 | Przegląd: dedicated node pools, spot, Karpenter vs CA, image preloading |
| Narzędzia developerskie (kubectx, k9s, Lens, Telepresence) | D5 | Cheatsheet — bez warsztatu, rekomendacja do samodzielnej instalacji |

---

## Format ćwiczenia

Każde ćwiczenie znajduje się w `dayN/<NN_topic>/`:

```
day1/01_nginx_image/
├── README.md          # cel, kontekst, prereqs, kroki, pytania kontrolne, linki
├── *.yaml / *.sh      # manifesty / skrypty
└── solution.md        # rozwiązanie + wyjaśnienie (opcjonalne)
```

**README zawiera:**
- 🎯 **Cel** (1 zdanie)
- 📚 **Kontekst** (3-5 zdań — po co to w produkcji)
- ✅ **Prereqs** (klaster, narzędzia, helm repo)
- 📝 **Zadanie** — kroki numerowane
- 🤔 **Pytania kontrolne** — 3-5 pytań do dyskusji
- 🔗 **Linki** — oficjalna dokumentacja

---

## Środowisko ćwiczeniowe

```bash
./setup-cluster.sh
```

Stawia lokalny K3d klaster z preinstall'd:
- **Envoy Gateway** (Gateway API impl) — D2/07
- **cert-manager** — D2/07 + D4/04
- **metrics-server** — D3/03 + D3/04 HPA

Pełna instalacja narzędzi (kubectl, helm, k3d, trivy, cosign) — patrz `SETUP.md`.
