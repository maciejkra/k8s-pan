# Zadanie

## Część 1 — Generic Secret + konsumpcja

1. Stwórz Secret z manifestu:
   ```bash
   kubectl apply -f secret-generic.yaml
   ```

2. Sprawdź zawartość — **zwróć uwagę że wartości są base64** (NIE encryption!):
   ```bash
   kubectl get secret app-credentials -o yaml
   # data.db-password: c3VwZXJzZWNyZXQtY2hhbmdlLW1l

   # Dekoduj
   kubectl get secret app-credentials -o jsonpath='{.data.db-password}' | base64 -d
   # supersecret-change-me
   ```

3. Wdroż consumer Poda:
   ```bash
   kubectl apply -f consumer-pod.yaml
   kubectl wait --for=condition=ready pod/secret-consumer --timeout=30s
   ```

4. Zobacz konsumpcję:
   ```bash
   kubectl logs secret-consumer
   # === ENV ===
   # DB_USER=admin
   # DB_PASSWORD=supersecret-change-me
   # === VOLUME ===
   # -r-------- 1 root root ... db-user
   # -r-------- 1 root root ... db-password
   # admin
   # supersecret-change-me

   # Exec do poda i sprawdź na żywo
   kubectl exec -it secret-consumer -- sh -c 'echo $DB_USER; cat /etc/secret/db-password'
   ```

5. **Eksperyment "env vs volume refresh":**
   ```bash
   # Zmień Secret
   kubectl patch secret app-credentials -p '{"stringData":{"db-password":"new-value"}}'

   # Poczekaj ~60s, potem:
   kubectl exec -it secret-consumer -- cat /etc/secret/db-password
   # new-value (zrefreshowane z volume — kubelet periodic sync)

   kubectl exec -it secret-consumer -- sh -c 'echo $DB_PASSWORD'
   # supersecret-change-me (env NIE jest refreshowany — Pod musiałby być restartowany)
   ```

## Część 2 — Docker registry Secret (private images)

```bash
# Hasło przez stdin (nie shell history!)
read -sp "GHCR PAT: " GHCR_TOKEN; echo
kubectl create secret docker-registry ghcr-pull-secret \
  --docker-server=ghcr.io \
  --docker-username=TwojGHUser \
  --docker-password="$GHCR_TOKEN" \
  --docker-email=unused
unset GHCR_TOKEN   # wyczyść z pamięci shell'a
```

Użycie w Pod:
```yaml
spec:
  imagePullSecrets:
    - name: ghcr-pull-secret
  containers:
    - name: app
      image: ghcr.io/my-org/private-app:v1.0.0
```

**Pytanie:** co zrobić żeby WSZYSTKIE Pody w namespace automatycznie dostawały ten `imagePullSecret`? (Hint: ServiceAccount default.)

## Część 3 — TLS Secret (dla Gateway API / Ingress)

```bash
# Wygeneruj self-signed cert do demo (w produkcji: cert-manager z D2/07)
openssl req -x509 -newkey rsa:2048 -nodes -days 1 \
  -keyout /tmp/server.key -out /tmp/server.crt \
  -subj "/CN=demo.local" -addext "subjectAltName=DNS:demo.local"

# Stwórz TLS Secret
kubectl create secret tls demo-tls \
  --cert=/tmp/server.crt \
  --key=/tmp/server.key

# Użycie: certificateRefs.name: demo-tls w listener Gateway (D2/07 gateway-https.yaml)
rm /tmp/server.{crt,key}
```

## Pytania

- Dlaczego preferujesz `stringData` nad `data` w manifestach? Kiedy jednak `data` jest niezbędne?
- Co robi `immutable: true`? Kiedy warto go ustawiać?
- Jaka różnica między Secret **refresh** w env vs w volume mount? (Dydaktycznie: pokaż eksperyment wyżej.)
- Dlaczego K8s 1.24+ nie tworzy auto-tokens dla SA? Co się zmieniło?
- Kiedy K8s Secrets to NIE wystarczy i trzeba Vault/ESO? Wymień 3 scenariusze.

## Bonus

Zrób Secret **immutable** (`immutable: true`), próbuj go zmienić:
```bash
kubectl patch secret app-credentials -p '{"stringData":{"api-key":"new"}}'
# Spodziewany error: forbidden: field is immutable when `immutable` is set
```
Jak wymienić immutable Secret bez downtime Poda? (Hint: nowa nazwa + patch Pod spec.)
