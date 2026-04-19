# 03 — OIDC Authentication

## Cel
Skonfigurować klaster K8s do uwierzytelniania użytkowników przez **OpenID Connect** (Google, Okta, Auth0, Dex). Używać `kubelogin` plugin do automatycznego refresh.

## Kontekst
**OIDC** = OAuth 2.0 + JSON Web Tokens (JWT). User loguje się u IdP (Identity Provider) → dostaje **id_token** (JWT z claims: email, group, expire) → wysyła do K8s API jako Bearer.

K8s API server weryfikuje JWT podpis przez public key od IdP, ekstraktuje claims, mapuje na K8s username/group.

Użycie: SSO dla całej organizacji. User loguje się raz w przeglądarce, kubectl używa refresh tokenu w tle.

**Komponenty**:
- **IdP** (Google, Okta, Auth0, GitHub via Dex) — wystawia id_token
- **kube-apiserver flags**: `--oidc-issuer-url`, `--oidc-client-id`, `--oidc-username-claim`, `--oidc-groups-claim`
- **kubelogin plugin** — automatyzuje OIDC flow (browser-based) + refresh

## Prereqs
- IdP konto (Google, Okta) z założoną OAuth aplikacją
- `kubelogin` (kubectl plugin: `brew install int128/kubelogin/kubelogin`)
- Kind/K3d cluster z OIDC-enabled apiserver (patrz `kind.yaml`)

## Zadanie

1. **Setup OAuth aplikacji u IdP** (np. Google Cloud Console):
   - Application type: Desktop app (lub Native)
   - Authorized redirect: `http://localhost:8000`
   - Zapisz `CLIENT_ID` i `CLIENT_SECRET`

2. Skonfiguruj kubelogin (zastąp placeholdery swoimi wartościami):
   ```bash
   kubectl oidc-login setup \
     --oidc-issuer-url=https://accounts.google.com \
     --oidc-client-id=<TWOJ_CLIENT_ID> \
     --oidc-client-secret=<TWOJ_CLIENT_SECRET> \
     --oidc-extra-scope=email
   ```

3. Uruchom Kind cluster z OIDC:
   ```bash
   kind create cluster --config ./kind.yaml --name workshop
   ```

4. Skonfiguruj kubectl context używający OIDC:
   ```bash
   kubectl config set-credentials oidc-user \
     --exec-api-version=client.authentication.k8s.io/v1beta1 \
     --exec-command=kubectl \
     --exec-arg=oidc-login \
     --exec-arg=get-token \
     --exec-arg=--oidc-issuer-url=https://accounts.google.com \
     --exec-arg=--oidc-client-id=<TWOJ_CLIENT_ID> \
     --exec-arg=--oidc-client-secret=<TWOJ_CLIENT_SECRET>
   ```

5. Test:
   ```bash
   kubectl --user=oidc-user get pods
   # Otworzy się browser z Google login
   # Po zalogowaniu kubectl użyje id_token
   ```

6. RBAC dla emaila:
   ```bash
   kubectl create rolebinding my-access \
     --clusterrole=view \
     --user=twoj.email@example.com
   ```

## Pytania kontrolne
1. JWT id_token wygasł — co dalej? (Hint: refresh_token, kubelogin auto)
2. OIDC vs LDAP vs SAML — co K8s natywnie wspiera?
3. Jak audit-logować kto co zrobił przez OIDC? (Hint: K8s audit logs zawierają `userInfo`)
4. Dlaczego **NIE** commit'ować client_secret do repo? (Co zrobić zamiast?)

## Linki
- [OIDC docs K8s](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#openid-connect-tokens)
- [kubelogin](https://github.com/int128/kubelogin)
- [Dex](https://dexidp.io/docs/kubernetes/) — OIDC frontend dla LDAP/GitHub/etc.

## Bezpieczeństwo
**Nie commituj `--oidc-client-secret` do publicznego repozytorium.** W produkcji:
- Trzymaj w Vault / cloud KMS
- Używaj per-user kubeconfig generowany przez automation
- Public clients (PKCE flow) eliminują potrzebę secret w aplikacji desktopowej
