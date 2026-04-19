# 01 — Token Authentication (ServiceAccount)

## Cel
Stworzyć ServiceAccount, wygenerować token, użyć go z `kubectl` jako alternative tożsamość.

## Kontekst
ServiceAccount tokens mają dwa modele:
1. **Legacy (do K8s 1.23)** — automatycznie utworzony Secret z permanentnym tokenem
2. **BoundToken (od 1.24)** — tokeny generowane przez `kubectl create token`, wygasają po ustalonym czasie (default 1h, max 24h)

Legacy token w produkcji = ryzyko (skradziony token nie wygasa). Best practice: BoundToken + przepowiednia odnawiania w aplikacjach.

## Prereqs
- K3d/Kind cluster

## Zadanie

1. Stwórz namespace:
   ```bash
   kubectl create ns maciek
   ```

2. Stwórz ServiceAccount + (legacy) Secret z tokenem:
   ```bash
   kubectl apply -f sa.yaml
   ```

3. Wyciągnij token:
   ```bash
   TOKEN=$(kubectl get -n maciek secret maciek-secret -o jsonpath='{.data.token}' | base64 --decode)
   echo "$TOKEN" | head -c 50
   ```

4. Skonfiguruj kubectl context używający tego tokenu:
   ```bash
   kubectl config set-credentials maciek --token=$TOKEN
   kubectl config set-context maciek-context --cluster=docker-desktop --namespace=default --user=maciek
   kubectl --context=maciek-context get pods
   # Forbidden — bo SA nie ma jeszcze uprawnień
   ```

5. Dodaj uprawnienia (RBAC):
   ```bash
   kubectl apply -f rbac.yaml
   kubectl --context=maciek-context get pods
   # Działa
   ```

6. Bonus — alternatywa **BoundToken** (rekomendowana w nowych klastrach):
   ```bash
   TOKEN_BOUND=$(kubectl create token maciek-sa -n maciek --duration=1h)
   echo "$TOKEN_BOUND"
   ```

## Pytania kontrolne
1. Legacy SA Secret token vs BoundToken — kluczowe różnice w bezpieczeństwie?
2. Dlaczego ServiceAccount jest dla **Pod-ów**, a nie dla użytkowników-ludzi?
3. Co zrobić gdy ServiceAccount token został skompromitowany?
4. Jak rotować tokeny w działających aplikacjach? (Hint: app musi re-load token z dysku)

## Linki
- [RBAC description](https://kubernetes.io/docs/reference/access-authn-authz/authorization/#determine-the-request-verb)
- [RBAC good practices](https://kubernetes.io/docs/concepts/security/rbac-good-practices/)
- [BoundServiceAccountTokenVolume](https://kubernetes.io/docs/concepts/configuration/secret/#serviceaccount-token-secrets)
