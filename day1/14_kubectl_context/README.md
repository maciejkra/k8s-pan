# 14 — kubectl context i kubeconfig

## Cel
Zrozumieć strukturę pliku `kubeconfig`, zarządzać wieloma klastrami / użytkownikami / namespace przez `kubectl config`. Bez zewnętrznych narzędzi (kubectx/kubens — te są w prezentacji).

## Kontekst
`kubectl` używa **kubeconfig** — pliku YAML mapującego:
- **clusters** — adresy API serverów + CA
- **users** — credentials (cert, token, OIDC)
- **contexts** — kombinacja `cluster + user + namespace`

Domyślnie: `~/.kube/config`. Można nadpisać przez `KUBECONFIG=path1:path2:...` (kolon-separated, jak `PATH`).

W produkcji typowy programista ma **5-15 contexts** (dev / staging / prod × per region / per zespół). Bez zarządzania — łatwo wykonać `kubectl delete pod` na produkcji zamiast dev.

## Prereqs
- K3d cluster z `./setup-cluster.sh`
- Drugi cluster do testów (utworzymy w trakcie ćwiczenia)

## Zadanie

1. Sprawdź aktualny kubeconfig:
   ```bash
   kubectl config view
   kubectl config current-context
   # k3d-training
   ```

2. Sprawdź dokąd kubeconfig wskazuje:
   ```bash
   kubectl config view --raw -o jsonpath='{.clusters[?(@.name=="k3d-training")].cluster.server}'
   ```

3. Stwórz drugi K3d cluster (sandbox do testów):
   ```bash
   k3d cluster create sandbox --servers 1 --agents 1
   kubectl config get-contexts
   # Powinny być dwa: k3d-training i k3d-sandbox
   ```

4. Przełącz na sandbox i sprawdź gdzie jesteś:
   ```bash
   kubectl config use-context k3d-sandbox
   kubectl get nodes                    # tylko 2 nody zamiast 3
   ```

5. **Bezpieczna komenda** — wskaż explicit kontekst zamiast polegać na current:
   ```bash
   kubectl --context=k3d-training get pods -A
   kubectl --context=k3d-sandbox get nodes
   ```

6. Ustaw default namespace dla bieżącego context:
   ```bash
   kubectl config set-context --current --namespace=kube-system
   kubectl get pods                     # już bez -n kube-system
   kubectl config set-context --current --namespace=default     # reset
   ```

7. **Merge dwóch kubeconfigs** (typowy scenariusz: dostałeś kubeconfig.prod.yaml od admina):
   ```bash
   # Symuluj: eksport sandbox jako osobny plik
   kubectl --context=k3d-sandbox config view --raw --minify > /tmp/sandbox.kubeconfig
   
   # Merge przez KUBECONFIG env
   KUBECONFIG=~/.kube/config:/tmp/sandbox.kubeconfig kubectl config view --merge --flatten > /tmp/merged.kubeconfig
   
   # Albo zwyczajnie skopiuj jako new file (nie nadpisuj swojego głównego!)
   cp /tmp/merged.kubeconfig ~/.kube/config.merged
   KUBECONFIG=~/.kube/config.merged kubectl config get-contexts
   ```

8. **Custom prompt** — pokazuj aktualny context w shell:
   ```bash
   # Bash/zsh prompt fragment
   echo 'PS1="[$(kubectl config current-context):$(kubectl config view --minify -o jsonpath={..namespace})] $PS1"' >> ~/.zshrc
   ```

9. Sprzątnij sandbox:
   ```bash
   k3d cluster delete sandbox
   kubectl config get-contexts            # k3d-sandbox zniknie automatycznie
   ```

## Pytania kontrolne
1. Co się stanie gdy zrobisz `kubectl delete --all` z złym current-context? Jak temu zapobiec?
2. Dlaczego `KUBECONFIG=path1:path2` jest lepsze niż edycja jednego pliku?
3. Jak wpłynąć na kubeconfig dla CI/CD (gdzie nie ma interactive prompt)?
4. Co to są **service account tokens** w kubeconfig vs **OIDC tokens** vs **client certs**? Kiedy które?

## Linki
- [Configure Access to Multiple Clusters](https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/)
- [kubectl cheatsheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [kube-ps1](https://github.com/jonmosco/kube-ps1) — gotowy prompt z kontekstem (wzorzec w prezentacji o narzędziach)
