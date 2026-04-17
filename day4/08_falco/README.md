# 08 — Falco: runtime security

## Cel
Wdrożyć Falco w klastrze, zaobserwować detekcję podejrzanych zachowań runtime, napisać własną regułę.

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

Output: structured logs (JSON) → SIEM (Splunk, Datadog, Elastic) lub Falcosidekick → Slack/PagerDuty/webhooks.

## Prereqs
- K3d cluster (eBPF jest używane przez K3d/K3s na Linuxie; macOS host = K3d w VM = działa)

## Zadanie

1. Instalacja przez Helm:
   ```bash
   helm repo add falcosecurity https://falcosecurity.github.io/charts
   helm repo update
   helm install falco falcosecurity/falco \
     -n falco --create-namespace \
     --set driver.kind=ebpf \
     --set tty=true \
     --set falcoctl.artifact.install.enabled=true \
     --set falcoctl.artifact.follow.enabled=true \
     --set "falco.rules_files={/etc/falco/falco_rules.yaml,/etc/falco/falco_rules.local.yaml,/etc/falco/k8s_audit_rules.yaml,/etc/falco/rules.d}"
   kubectl wait --for=condition=ready -n falco pod -l app.kubernetes.io/name=falco --timeout=3m
   ```

2. Sprawdź, że Falco działa:
   ```bash
   kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=20 | grep -i ready
   ```

3. Triggeruj built-in regułę "Terminal shell in container":
   ```bash
   kubectl apply -f trigger-pod.yaml
   kubectl wait --for=condition=ready pod/innocent-app
   kubectl exec -it innocent-app -- sh
   # w innym terminalu:
   kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=20 | grep -i shell
   ```

4. Zaaplikuj custom rule:
   ```bash
   kubectl apply -f custom-rules.yaml
   # ConfigMap montuje plik /etc/falco/rules.d/custom.yaml
   kubectl rollout restart -n falco daemonset/falco
   kubectl wait --for=condition=ready -n falco pod -l app.kubernetes.io/name=falco --timeout=2m
   ```

5. Triggeruj custom rule (zapis do `/etc/`):
   ```bash
   kubectl exec -it innocent-app -- sh -c "echo malicious >> /etc/passwd"
   kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=20 | grep -i custom
   ```

## Pytania kontrolne
1. eBPF vs kernel module — kiedy które?
2. Falco generuje DUŻO eventów. Jak filtrować w produkcji?
3. Jak wyciągać alerty Falco do Slacka? (Hint: Falcosidekick)
4. Falco wykrył shell w kontenerze — co dalej? (Auto-respond? Manual?)

## Linki
- [Falco docs](https://falco.org/docs/)
- [Falco rules reference](https://falco.org/docs/rules/)
- [Falcosidekick](https://github.com/falcosecurity/falcosidekick)
