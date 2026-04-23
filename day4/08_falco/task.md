# Zadanie

## Część 1 — Install Falco + load custom rules via Helm

**Ważne**: custom rules muszą być podane przez `helm --set-file customRules."custom-rules\.yaml"` przy install/upgrade, inaczej ConfigMap jest osierocona (nie mountowana do DaemonSet).

```bash
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update

# Install z custom rules w jednym kroku (NIE jako ConfigMap)
helm install falco falcosecurity/falco \
  -n falco --create-namespace \
  --set driver.kind=modern_ebpf \
  --set tty=true \
  --set falcoctl.artifact.install.enabled=true \
  --set falcoctl.artifact.follow.enabled=true \
  --set-file customRules."custom-rules\.yaml"=./custom-rules.yaml

kubectl wait --for=condition=ready -n falco pod -l app.kubernetes.io/name=falco --timeout=3m
```

Sprawdź że custom rules są wczytane:
```bash
kubectl exec -n falco -it daemonset/falco -- \
  ls /etc/falco/rules.d/
# custom-rules.yaml

kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=50 | grep -i "rules"
# (custom) Loaded rules from file /etc/falco/rules.d/custom-rules.yaml
```

> **Alternatywa**: jeśli custom rules się zmieniają często, trzymaj je jako `helm --values values.yaml` → commit w Git → `helm upgrade falco -f values.yaml` przy każdej zmianie.
>
> ConfigMap `custom-rules.yaml` w katalogu **nie jest** deploy'owana przez `kubectl apply` — ten plik służy tylko jako źródło dla `--set-file`.

## Część 2 — Triggeruj built-in rule "Terminal shell"

```bash
kubectl apply -f trigger-pod.yaml
kubectl wait --for=condition=ready pod/innocent-app --timeout=30s

# W drugim terminalu:
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=50 -f | grep -i "shell\|notice"

# W pierwszym:
kubectl exec -it innocent-app -- sh
# Wpisz: exit
```

Spodziewany alert w logu Falco:
```
{"output":"A shell was spawned in a container with an attached terminal (user=root user_loginuid=0 ...)","priority":"Notice","rule":"Terminal shell in container",...}
```

## Część 3 — Trigger custom rule (zapis do /etc)

```bash
# Pod nadal żyje z poprzedniego kroku
kubectl exec -it innocent-app -- sh -c "echo malicious >> /etc/passwd"

# Sprawdź logi Falco
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=20 | grep -i "Custom rule"
```

Spodziewane:
```
{"output":"Custom rule: zapis do /etc wewnątrz kontenera (user=root file=/etc/passwd proc=sh container=app image=alpine)","priority":"Warning","rule":"Custom - Write to /etc",...}
```

## Część 4 — Trigger drugiej custom rule (connect 4444)

```bash
# Alpine nie ma netcat - install albo użyj innej apki:
kubectl exec -it innocent-app -- sh -c "apk add -q netcat-openbsd && nc -v 192.0.2.1 4444 -w 1 || true"
```

Logi Falco powinny pokazać custom rule "Outbound connection to suspicious port".

## Część 5 — Integracja z Slack przez Falcosidekick (bonus)

```bash
helm upgrade falco falcosecurity/falco \
  -n falco --reuse-values \
  --set falcosidekick.enabled=true \
  --set falcosidekick.webui.enabled=true \
  --set falcosidekick.config.slack.webhookurl="<twoj-slack-webhook>"

kubectl port-forward -n falco svc/falco-falcosidekick-ui 2802
# Otwórz http://localhost:2802 — UI z eventami
```

## Część 6 — Cleanup

```bash
kubectl delete -f trigger-pod.yaml
helm uninstall falco -n falco
```

## Pytania

1. **eBPF vs kernel module** — kiedy który? (Hint: kernel module wymaga kernel-headers = nie działa w bezgłowych dystrybucjach.)
2. **Dlaczego `--set-file customRules` zamiast `kubectl apply -f ConfigMap`?** (Hint: chart Falco ma custom rendering, wymaga values nie CRD.)
3. **Priority levels** (DEBUG/INFO/NOTICE/WARNING/ERROR/CRITICAL/ALERT/EMERGENCY) — jak wpływa na falcosidekick routing?
4. **Falco + Kubernetes audit** — drugi driver (poza syscalls) który obserwuje `kubectl` commands. Kiedy używać?
5. **Bonus**: **eBPF + Spectre/Meltdown** — czy Falco eBPF jest bezpieczny na hosts gdzie eBPF JIT jest wyłączony?

## Troubleshooting

Patrz `solution.md`.
