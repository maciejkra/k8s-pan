# 06 — AuthN i AuthZ: ServiceAccount + RBAC (intro)

## Cel
Zrozumieć jak Pod uwierzytelnia się przy K8s API przez ServiceAccount, jak RBAC autoryzuje konkretne akcje. Punkt wejścia do podsekcji `01_token`, `02_cert`, `03_oidc`.

## Kontekst
Każde żądanie do API serwera K8s przechodzi przez:
1. **AuthN (uwierzytelnianie)** — kim jesteś? Strategie: ServiceAccount token, x509 client cert, OIDC, webhook.
2. **AuthZ (autoryzacja)** — co możesz? RBAC (najpopularniejsze), ABAC, webhook.
3. **Admission** — czy żądanie jest poprawne? (D4/03)

**ServiceAccount** = identyfikator dla **Pod-ów** (in-cluster workloads). Każdy Pod ma SA (default jeśli nie wyspecyfikowany). SA token jest auto-mountowany w `/var/run/secrets/kubernetes.io/serviceaccount/`.

**RBAC** = role-based access control:
- `Role` / `ClusterRole` — definicja uprawnień ("get/list/watch pods w namespace X")
- `RoleBinding` / `ClusterRoleBinding` — przypisanie roli do user/group/SA

## Prereqs
- K3d/Kind cluster

## Zadanie

1. Stwórz ServiceAccount + ClusterRole + RoleBinding + Pod używający tej SA:
   ```bash
   kubectl apply -f sa.pod-reader.yaml
   kubectl apply -f cluster-role.yaml
   kubectl apply -f rbac.yaml
   kubectl apply -f pod.yml
   ```

2. **Z wewnątrz Pod-a** — odczytaj token i zapytaj API serwera:
   ```bash
   kubectl exec -it <pod> -- sh -c '
     TOKEN=$(cat /run/secrets/kubernetes.io/serviceaccount/token)
     curl -H "Authorization: Bearer $TOKEN" \
       https://kubernetes/api/v1/namespaces/default/pods/ --insecure
   '
   ```

3. **Z kubectl wewnątrz Pod-a** (uproszczenie):
   ```bash
   kubectl apply -f pod-kctl.yaml
   kubectl logs pod-reader
   ```

4. **Sprawdź uprawnienia** SA bez wykonywania akcji:
   ```bash
   kubectl auth can-i list pods --as=system:serviceaccount:default:pod-reader
   # yes
   kubectl auth can-i delete pods --as=system:serviceaccount:default:pod-reader
   # no
   ```

## Pytania kontrolne
1. Default ServiceAccount — dlaczego trzeba ostrożnie z `automountServiceAccountToken: true`?
2. Role vs ClusterRole — kiedy które?
3. Co to są **aggregated ClusterRoles** (np. `view`, `edit`, `admin`)?
4. Jak zaimplementować "team A widzi tylko swoje namespace, ale wszystkie klastry"? (Hint: ClusterRoleBinding + Group)

## Podkatalogi (różne strategie AuthN)

- `01_token/` — uwierzytelnianie przez ServiceAccount token (best dla CI/CD)
- `02_cert/` — uwierzytelnianie przez client x509 certificate (klasyczne dla adminów)
- `03_oidc/` — uwierzytelnianie przez OpenID Connect (best dla użytkowników z SSO)

## Linki
- [Authentication overview](https://kubernetes.io/docs/reference/access-authn-authz/authentication/)
- [RBAC docs](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [RBAC good practices](https://kubernetes.io/docs/concepts/security/rbac-good-practices/)
