# Solution — 14_kubectl_context

## Odpowiedzi

### `kubectl delete --all` na złym kontekście
Klasyczny incident. Mitigation:
1. **Wymusić explicit `--context`** w skryptach destruktywnych:
   ```bash
   alias kubectl-prod='kubectl --context=production-eu-west-1'
   ```
2. **Read-only kubeconfig dla codziennego use**, write-context tylko gdy potrzebny:
   ```bash
   export KUBECONFIG=~/.kube/config-readonly
   ```
3. **Production has admission webhook** blokujący `delete --all` (OPA/Gatekeeper, D4/09):
   ```rego
   violation[{"msg": "delete --all forbidden in production"}] {
     input.review.operation == "DELETE"
     input.review.dryRun == false
     count(input.review.options.gracePeriodSeconds) == 0
     # ... + label selector check
   }
   ```
4. **Prompt zmieniający kolor per context** (czerwone tło dla produkcji):
   ```bash
   case "$(kubectl config current-context)" in
     *prod*) PROMPT_COLOR="\033[1;41m" ;;     # red bg
     *)      PROMPT_COLOR="\033[1;32m" ;;
   esac
   ```

### KUBECONFIG=multi vs jeden plik
Multi:
- ✅ Każdy klaster jako osobny plik (łatwo kopiować, wersjonować osobno)
- ✅ Można szybko "switch off" klaster (usuń z PATH-like list)
- ✅ Bezpieczniej (mniej accidentaal commit prod credentials)
- ❌ Trochę bardziej złożone do debugowania

Jeden plik (default):
- ✅ Prosty, jeden source of truth
- ❌ Większy, łatwiej coś rozbić edycją
- ❌ Trudniej selectywnie udostępnić

### Kubeconfig w CI/CD
Best practices:
1. **Service Account token** zamiast user OIDC (bo CI nie ma browsera dla SSO):
   ```bash
   kubectl create serviceaccount ci-deployer -n production
   kubectl create clusterrolebinding ci-deployer --serviceaccount=production:ci-deployer --clusterrole=edit
   TOKEN=$(kubectl create token ci-deployer --duration=24h)
   ```
2. **Ephemeral tokens** (short-lived, bound to job)
3. **OIDC federation** (GitHub Actions OIDC → cloud IAM → cluster) — bez storage tokenów
4. **No long-lived kubeconfig in secrets** — generuj w workflow, nie commituj

### Auth methods comparison
| Method | Lifetime | Use case | Risk |
|---|---|---|---|
| **ServiceAccount token (legacy)** | infinite | in-cluster Pod, CI | nie wygasa — long-term theft |
| **ServiceAccount token (BoundToken, K8s 1.20+)** | 1h auto-refresh | in-cluster Pod | minimal |
| **Client certificate (x509)** | per cert (typ. 1y) | admin user, kubeadm bootstrap | hard to revoke (no CRL by default) |
| **OIDC (Dex, Auth0, Google)** | per token (typ. 1h) | human user, SSO | depends on IdP |
| **Webhook token** | custom | wrapper dla custom auth | depends on impl |

W produkcji: **OIDC dla ludzi**, **BoundToken dla Podów**, **ephemeral SA token dla CI**.

## Walidacja

```bash
$ kubectl config get-contexts
CURRENT   NAME            CLUSTER         AUTHINFO              NAMESPACE
*         k3d-sandbox     k3d-sandbox     admin@k3d-sandbox
          k3d-training    k3d-training    admin@k3d-training

$ kubectl --context=k3d-training get nodes
NAME                       STATUS   ROLES                  AGE
k3d-training-server-0      Ready    control-plane,master   2h
k3d-training-agent-0       Ready    <none>                 2h
k3d-training-agent-1       Ready    <none>                 2h

$ kubectl --context=k3d-sandbox get nodes
NAME                      STATUS   ROLES                  AGE
k3d-sandbox-server-0      Ready    control-plane,master   1m
k3d-sandbox-agent-0       Ready    <none>                 1m
```

## Cross-link
- D2/06 auth — szczegóły OIDC, cert x509, ServiceAccount tokens
- D5/06 install — kubeadm generuje pierwszy kubeconfig (`/etc/kubernetes/admin.conf`)
- Prezentacja "Narzędzia" — kubectx (szybsze niż `kubectl config use-context`), kubens (namespace switching), kube-ps1 (prompt)
