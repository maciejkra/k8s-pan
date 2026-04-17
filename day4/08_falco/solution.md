# Solution — 08_falco

## Spodziewane eventy

### Built-in rule "Terminal shell in container"
```json
{
  "output": "20:34:11.123: Notice A shell was spawned in a container with an attached terminal (user=root user_loginuid=-1 k8s.ns=default k8s.pod=innocent-app container=innocent-app shell=sh ...)",
  "priority": "Notice",
  "rule": "Terminal shell in container",
  "time": "2026-04-17T20:34:11.123Z",
  "tags": ["container", "shell", "mitre_execution", "T1059"]
}
```

### Custom rule "Write to /etc"
```json
{
  "output": "Custom rule: zapis do /etc wewnątrz kontenera (user=root file=/etc/passwd container=innocent-app image=alpine)",
  "priority": "Warning",
  "rule": "Custom - Write to /etc",
  "tags": ["custom", "filesystem"]
}
```

## Odpowiedzi

### eBPF vs kernel module
- **eBPF** (Falco modern driver):
  - ✅ nie wymaga modułu jądra (przyjazne dla managed K8s — EKS/GKE)
  - ✅ łatwiejsza dystrybucja (jeden binary)
  - ✅ kernel ≥ 5.8 (BTF support)
  - ❌ trochę większy overhead per event
- **Kernel module** (legacy):
  - ✅ działa na starszych kernelach
  - ❌ wymaga DKMS / pre-built per kernel version
  - ❌ utrudnia patching kernela

Wybór: eBPF dla nowych klastrów (>= 2022), KM tylko gdy musisz.

### Filtrowanie w produkcji
Falco sam może mieć tysiące alertów dziennie. Strategie:
1. **Disable noisy rules** w `falco.yaml` (`disabled_rules: [name1, name2]`)
2. **Tune existing rules** — modyfikuj `condition` żeby wykluczyć known-good (np. wyłączyć alerty dla CI namespace)
3. **Severity threshold** — Falcosidekick filtruje po priority, tylko CRITICAL/ERROR idzie do PagerDuty
4. **Aggregation** — Loki/SIEM grupuje podobne eventy (10× shell w 5min od tego samego user → jeden alert)

### Falcosidekick → Slack
```bash
helm install falcosidekick falcosecurity/falcosidekick \
  -n falco \
  --set config.slack.webhookurl=https://hooks.slack.com/services/XXX \
  --set config.slack.minimumpriority=warning
```

Falco → Falcosidekick → 50+ outputs (Slack, PagerDuty, Elasticsearch, S3, Kafka, AWS Lambda, …).

### Auto-respond vs manual
**Auto-respond** możliwy przez Falco Talon (response engine):
- shell wykryty → `kubectl delete pod`
- writeable mount → `kubectl exec ... mount -o remount,ro`
- outbound to bad IP → NetworkPolicy update

**Trade-off**: false positive może wyłączyć production. Standardowo:
- DEV → auto-respond OK
- STAGING → notify + manual approve
- PROD → tylko notify, manual response (incident response playbook)

## Walidacja

```bash
# 1. Pod uruchomiony, sleep
kubectl get pod innocent-app

# 2. Trigger built-in rule
kubectl exec -it innocent-app -- sh
exit

# 3. Sprawdź event
kubectl logs -n falco -l app.kubernetes.io/name=falco | grep -i "shell was spawned" | tail -3

# 4. Trigger custom rule
kubectl exec innocent-app -- sh -c 'echo backdoor >> /etc/hosts'

# 5. Custom event powinien pojawić się
kubectl logs -n falco -l app.kubernetes.io/name=falco | grep -i "Custom rule" | tail -3
```

## Cross-link
- D4/05 (SecurityContext readOnlyRootFilesystem) — zapobiega zapisowi do `/etc` proaktywnie. Falco wykrywa próby (defense in depth)
- D4/09 (OPA/Gatekeeper) — admission, prewencja. Falco — runtime, detekcja
- D5/04 (Grafana) — dashboard z Falco metrics
