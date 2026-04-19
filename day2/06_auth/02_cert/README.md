# 02 — Certificate Authentication (x509)

## Cel
Wygenerować klucz prywatny + CSR, podpisać przez K8s CA, używać jako tożsamość admin/dev w `kubectl`.

## Kontekst
**Client certificate auth** — klasyczna metoda dla użytkowników (kubeadm generuje admin cert). Każdy cert zawiera:
- **CN** (Common Name) → username
- **O** (Organization) → group(s)

Cert jest podpisywany przez CA klastra (`/etc/kubernetes/pki/ca.crt`). K8s API server weryfikuje cert, ekstraktuje CN i O, używa do AuthN.

**Plusy**: nie wymaga external IdP, działa offline.
**Minusy**: brak built-in revocation (cert ważny do expiry), trudne rotation.

W produkcji: cert dla admin emergency access, OIDC dla codziennego use.

## Prereqs
- K3d/Kind cluster
- `openssl`

## Zadanie

1. Wygeneruj klucz + CSR:
   ```bash
   openssl genrsa -out maciej.key 2048
   openssl req -new -key maciej.key -out maciej.csr -subj "/CN=maciej/O=workshop"
   ```

2. Submituj CSR do K8s API:
   ```bash
   # Edytuj csr.yaml żeby zawierało base64 CSR (cat maciej.csr | base64 | tr -d '\n')
   kubectl apply -f csr.yaml
   ```

3. Sprawdź i zaakceptuj CSR:
   ```bash
   kubectl get csr
   kubectl certificate approve maciej
   ```

4. Wyciągnij podpisany cert:
   ```bash
   kubectl get csr maciej -o jsonpath='{.status.certificate}' | base64 -d > maciej.crt
   ```

5. Skonfiguruj kubectl context używający certa:
   ```bash
   kubectl config set-credentials maciej \
     --embed-certs \
     --client-certificate=maciej.crt \
     --client-key=maciej.key
   kubectl config set-context maciej-context --cluster=docker-desktop --namespace=default --user=maciej
   kubectl --context=maciej-context get pods
   # Forbidden — cert daje tylko tożsamość, RBAC nadal potrzebny
   ```

6. Dodaj namespace i uprawnienia:
   ```bash
   kubectl create namespace workshop
   kubectl apply -f role.yaml
   kubectl apply -f rbac.yaml
   kubectl --context=maciej-context get pods --namespace=workshop
   # Działa
   ```

## Pytania kontrolne
1. Po co `O=workshop` w subject? Co to oznacza w RBAC? (Hint: group)
2. Jak revoke cert przed expiry? (Hint: standard K8s tego nie wspiera — używa się admission controller)
3. Cert vs Token vs OIDC — który jest najlepszy dla CI/CD? Dla admin? Dla dev?
4. Co zrobić gdy admin cert wygasł i utraciliśmy dostęp do klastra? (Hint: kubeadm certs renew)

## Linki
- [Managing TLS in K8s](https://kubernetes.io/docs/tasks/tls/managing-tls-in-a-cluster/)
- [Certificate Signing Requests](https://kubernetes.io/docs/reference/access-authn-authz/certificate-signing-requests/)
