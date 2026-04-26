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
> `custom-rules.yaml` w katalogu to **surowe reguły Falco** (nie manifest K8s) — `helm --set-file` wstawia jego treść 1:1 do values, chart tworzy z tego ConfigMap `falco-rules`. Nie aplikuj go przez `kubectl apply`.

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
kubectl exec innocent-app -- sh -c "echo malicious >> /etc/passwd"

# Sprawdź logi Falco
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=20 | grep -i "Custom rule"
```

Spodziewane:
```
... Warning Custom rule: zapis do /etc wewnątrz kontenera (user=root file=/etc/passwd proc=sh container=app ...)
```

> **macOS Apple Silicon / Docker Desktop:** Część 3 może nie firować — LinuxKit kernel ma uszkodzone tracepointy BPF dla `open`/`creat`, więc Falco nie wykrywa zapisu do plików (nawet wbudowane reguły plikowe nie działają). Reguły **sieciowe** (Część 4) firują normalnie. Na Linuxie / EC2 / WSL2 — Część 3 działa.

## Część 4 — Trigger drugiej custom rule (connect 4444)

Alpine 3.19 ma busybox `nc` natywnie — bez `apk add`:

```bash
kubectl exec innocent-app -- sh -c "nc -w 2 192.0.2.5 4444 || true"
```

Spodziewane w logach Falco:
```
... Critical Podejrzane wyjście TCP na port 4444 (container=app dest=192.0.2.5) ...
```

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
