# 08 — Falco: runtime security

## Cel
Wdrożyć Falco w klastrze, zaobserwować detekcję podejrzanych zachowań runtime, napisać własną regułę i **sprawdzić że działa** (ConfigMap mountowany przez helm values, nie osierocony).

## Kontekst
[Falco](https://falco.org/) (CNCF graduated) to **runtime detection** — w przeciwieństwie do Trivy/kube-bench (skanowanie statyczne), Falco obserwuje **co dzieje się na żywo** wewnątrz kontenera:
- syscalls (przez eBPF lub kernel module)
- K8s API audit events
- container runtime events

Wykrywa anomalie w czasie rzeczywistym:
- shell uruchomiony w produkcyjnym kontenerze
- proces zapisuje w `/etc/`
- nieoczekiwany wychodzący ruch sieciowy
- mount sensitive paths (`/proc`, `/var/run/docker.sock`)

Output: structured logs (JSON) → SIEM (Splunk, Datadog, Elastic) lub **Falcosidekick** → Slack/PagerDuty/webhooks.

## Driver matrix (ważne!)

| Runtime / Host | Rekomendowany driver |
|---|---|
| **K3s na Linux bare-metal / VM** | `modern_ebpf` (CO-RE, BTF, zero-install) |
| **K3d na Linux Docker host** | `modern_ebpf` (kernel host dostępny przez Docker) |
| **Kind na Linux** | `modern_ebpf` |
| **K3d/Kind na macOS Apple Silicon (arm64)** | `modern_ebpf` startuje, **ale reguły plikowe NIE firują** — LinuxKit kernel ma uszkodzone tracepointy `sys_enter_open`/`sys_enter_creat` (`libbpf: failed to determine tracepoint`). Reguły **sieciowe** (connect/sendto) działają normalnie |
| **K3d/Kind na macOS Intel (amd64)** | `modern_ebpf` zwykle działa pełniej; fallback `ebpf` (legacy, wymaga probe download) |
| **K3d/Kind na Windows WSL2** | `modern_ebpf` (WSL2 kernel ma BTF) |
| Dedicated kernel-module install | `kmod` — rzadko używane, wymaga `apt-get install falco-kernel-headers` |

**Jeśli `modern_ebpf` nie startuje**: sprawdź `kubectl logs -n falco <falco-pod>` — błąd "BPF program load failed" → spróbuj `ebpf` (legacy). Custom syscall rules mogą nie działać na bardzo starych kernelach.

> **macOS Apple Silicon — known limitation:** Część 3 ćwiczenia (zapis do `/etc/passwd` triggeruje custom rule "Write to /etc") **nie zadziała** na Docker Desktop arm64 — nawet wbudowane reguły plikowe nie firują z powodu BPF tracepoint failures w LinuxKit. Sprawdzono 2026-04 na Falco 0.43.1. Dla pełnej walidacji ćwiczenia użyj Linuksa, WSL2, lub maszyny x86. Część 4 (egress 4444 przez `nc`) **działa** na każdej platformie — używa innych syscalli (connect).

## Prereqs
- K3s / Kind / K3d cluster
- Kernel z BTF support (Linux 5.8+, większość dystrybucji od 2021+)

## Pliki

- `custom-rules.yaml` — surowe reguły Falco (ładowane przez `helm --set-file customRules`, NIE ConfigMap K8s); dwie reguły: write /etc, egress port 4444
- `trigger-pod.yaml` — prosty Pod `innocent-app` dla testowania

## Zadanie

Patrz [`task.md`](./task.md).

## Linki
- [Falco docs](https://falco.org/docs/)
- [Falco rules reference](https://falco.org/docs/rules/)
- [Falcosidekick](https://github.com/falcosecurity/falcosidekick)
- [Modern eBPF driver](https://falco.org/docs/install-operate/running/#modern-ebpf)
