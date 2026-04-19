# 02 — Helm: instalacja gotowego chartu (artifacthub.io)

## Cel
Zainstalować WordPress przez gotowy chart z [artifacthub.io](https://artifacthub.io/), zobaczyć values, override.

## Kontekst
[artifacthub.io](https://artifacthub.io) = "npm dla Helm chartów" — centralne repozytorium tysięcy gotowych chartów (Bitnami, oficjalne projekty, community).

Chart można instalować z:
- **OCI** (`oci://...`) — modern, jak Docker images, najnowsze
- **Helm repo** (`helm repo add` + `helm install repo/chart`) — klasyczne
- **Lokalny katalog** (`helm install ./mychart`) — własny chart

## Prereqs
- K3d/Kind cluster
- helm

## Zadanie

1. Search:
   ```bash
   helm search hub wordpress
   # Lista chartów wordpress z artifacthub
   ```

2. Install z OCI:
   ```bash
   helm install my-release oci://registry-1.docker.io/bitnamicharts/wordpress
   ```

3. Sprawdź zasoby:
   ```bash
   kubectl get all
   helm list
   ```

4. Override values:
   ```bash
   helm upgrade my-release oci://registry-1.docker.io/bitnamicharts/wordpress \
     --set wordpressUsername=admin \
     --set wordpressPassword=mypass \
     --set service.type=ClusterIP
   ```

5. Dump default values:
   ```bash
   helm show values oci://registry-1.docker.io/bitnamicharts/wordpress > values-default.yaml
   # Zobaczysz wszystkie konfigurowalne pola
   ```

6. Uninstall:
   ```bash
   helm uninstall my-release
   ```

## Pytania kontrolne
1. OCI registry vs klasyczne Helm repo — czemu OCI lepsze?
2. Bitnami vs oficjalne charty — różnice w jakości / supporcie?
3. Jak weryfikować kto opublikował chart? (Hint: provenance, signed charts)
4. Best practice: pinować wersję chartu czy `latest`?

## Linki
- [Helm docs](https://helm.sh/docs/)
- [artifacthub.io](https://artifacthub.io/)
- [OCI registries w Helm](https://helm.sh/docs/topics/registries/)
