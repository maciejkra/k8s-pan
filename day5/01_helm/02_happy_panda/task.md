# Zadanie

## Część 1 — Search artifacthub

```bash
helm search hub wordpress
# Lista chartów wordpress z artifacthub
```

## Część 2 — Install z OCI (modern)

```bash
helm install my-wp oci://registry-1.docker.io/bitnamicharts/wordpress \
  -n wordpress --create-namespace \
  -f values-override.yaml

# Poczekaj aż wszystkie Pody Running (WordPress + MariaDB)
kubectl wait --for=condition=ready pod -n wordpress --all --timeout=5m
```

## Część 3 — Sprawdź

```bash
kubectl get all -n wordpress
helm list -n wordpress
```

Port-forward żeby zobaczyć WP:
```bash
kubectl port-forward -n wordpress svc/my-wp 8080:80
# http://localhost:8080 → WordPress setup page
```

## Część 4 — Override runtime

```bash
# Zmień service.type w locie
helm upgrade my-wp oci://registry-1.docker.io/bitnamicharts/wordpress \
  -n wordpress \
  -f values-override.yaml \
  --set service.type=NodePort
```

## Część 5 — Dump full values

```bash
helm show values oci://registry-1.docker.io/bitnamicharts/wordpress > values-all.yaml
wc -l values-all.yaml
# ~1500 linii — wszystkie pola konfigurowalne
```

## Część 6 — Uninstall

```bash
helm uninstall my-wp -n wordpress
kubectl delete namespace wordpress
```

## Pytania

1. **OCI registry vs klasyczne Helm repo** — czemu OCI lepsze? (Hint: jednolita infrastruktura z Docker images, signature support przez cosign.)
2. **Bitnami vs oficjalne charty** — różnice w jakości / supporcie? (Hint: od 2025 Bitnami wymaga subscription dla enterprise features.)
3. Jak weryfikować kto opublikował chart? (Hint: `cosign verify`, provenance.)
4. Best practice: pinować wersję chartu czy `latest`? (Hint: zawsze pin + dependabot/renovate update.)
5. **Bonus**: dlaczego subchart `mariadb` ma osobne auth? Jak pass secret z parent chart do subchart?
