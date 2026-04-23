# 02 — Pod Security Admission (PSA)

## Cel
Zrozumieć **PodSecurity** admission: jak labele namespace egzekwują polityki baseline/restricted **bez** external webhook. Zobaczyć **negative test** — Pod który MUSI zostać odrzucony. Zobaczyć **controller-level trap** — klasyczną pułapkę gdzie Deployment "przechodzi" ale Pody nie startują.

## Kontekst
**Pod Security Admission (PSA)** to built-in admission controller (od K8s 1.23 beta, 1.25 stable). Zastępuje deprecated **PodSecurityPolicy (PSP)**.

Trzy **level** bezpieczeństwa:
- **privileged** — brak restrykcji (CI, trusted workloads, system)
- **baseline** — blokuje "oczywiste problemy": privileged, hostPath, hostNet, hostPID, allowedProcMountTypes. **Root user nadal dozwolony**.
- **restricted** — pełen hardening: runAsNonRoot=true, readOnlyRootFilesystem preferowane, drop ALL capabilities, seccompProfile=RuntimeDefault

Trzy **mode** aplikacji:
- **enforce** — odrzuć Pod
- **audit** — zapisz event do audit log
- **warn** — wyślij warning do `kubectl` output

Label na NS:
```yaml
pod-security.kubernetes.io/<MODE>: <LEVEL>
pod-security.kubernetes.io/<MODE>-version: <VERSION>    # latest lub v1.32 itp.
```

Typowa strategia "ease-in":
```yaml
pod-security.kubernetes.io/enforce: baseline   # minimum dla prod
pod-security.kubernetes.io/audit: restricted   # zbieraj dane "co by się zablokowało"
pod-security.kubernetes.io/warn: restricted    # ostrzegaj deva przy apply
```

Po jakimś czasie: `enforce: restricted`, gdy zespół dopasuje swoje manifesty.

### Dlaczego ten moduł miał błąd

Wcześniejsza wersja tego ćwiczenia miała TYLKO `enforce: baseline` + nginx (root). Baseline **pozwala na root** → nic nie było blokowane. Student widział "zielony Deployment" i nie zrozumiał PSA. **Obecna wersja** ma DWA namespace — baseline (demo "łagodny") i restricted (negative test + controller-level trap).

## Prereqs
- K3s / Kind / K3d cluster (dowolny z K8s ≥1.25)

## Pliki

| Plik | Rola |
|---|---|
| `ns.yaml` | 2 namespace: `psa-baseline` (enforce baseline, audit+warn restricted) + `psa-restricted` (enforce restricted) |
| `deployment-baseline.yaml` | Deployment w baseline NS — PRZEJDZIE (ale z warningiem) |
| `bad-pod-restricted.yaml` | Pod bez securityContext w restricted NS — **BLOKOWANY** |
| `hardened-pod-restricted.yaml` | Pod z pełnym hardening — PRZECHODZI w restricted |
| `deployment-controller-trap.yaml` | Deployment z złym Pod templatem w restricted — **trap demo** (Deployment OK, ReplicaSet w pętli) |

## Zadanie

Patrz [`task.md`](./task.md).

## Linki
- [Pod Security Admission](https://kubernetes.io/docs/concepts/security/pod-security-admission/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Migrate from PodSecurityPolicy to PSA](https://kubernetes.io/docs/tasks/configure-pod-container/migrate-from-psp/)
