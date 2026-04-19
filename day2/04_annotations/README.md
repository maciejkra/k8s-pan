# 04 — Annotations

## Cel
Zrozumieć różnicę annotation vs label, kiedy używać której. Dodawać/odczytywać annotations runtime.

## Kontekst
**Labels** (D1/07) = identyfikujące, używane przez K8s do matchowania (Service → Pod).
**Annotations** = non-identyfikujące, dla narzędzi i ludzi.

Typowe annotations w produkcji:
- `kubectl.kubernetes.io/last-applied-configuration` — wartość ostatniego apply (auto)
- `prometheus.io/scrape: "true"` — sygnał dla Prometheus
- `nginx.ingress.kubernetes.io/rewrite-target: /` — config dla Ingress controller
- `argocd.argoproj.io/sync-wave: "5"` — kolejność wdrażania w ArgoCD
- `cert-manager.io/cluster-issuer: letsencrypt-prod` — który issuer dla cert
- `owner: team-platform` — własność (żeby wiedzieć kogo pingować)

W odróżnieniu od labels — można w annotation zmieścić **dłuższe wartości**, JSON, base64, dowolne metadata.

## Prereqs
- K3d/Kind cluster z jakimś Pod-em (`myapp-pod` z label `app=myapp`)

## Zadanie

1. Przegląd struktury w manifestach:
   ```yaml
   metadata:
     annotations:
       key1: value1
       key2: value2
   ```

2. Dodaj annotation runtime do pierwszego pasującego Pod-a:
   ```bash
   POD=$(kubectl get pods -l app=myapp -o jsonpath='{.items[0].metadata.name}')
   kubectl annotate pod "$POD" workshop.test=verified
   ```

3. Odczytaj annotations:
   ```bash
   kubectl get pods "$POD" -o jsonpath='{.metadata.annotations}'
   kubectl describe pods "$POD"
   ```

4. Usuń annotation (znak `-` na końcu):
   ```bash
   kubectl annotate pod "$POD" workshop.test-
   ```

## Pytania kontrolne
1. Można selectować Pod-y po annotations? (`kubectl get pods -l ann=val`)
2. Po co `prometheus.io/scrape: "true"` jest annotation a nie label?
3. `kubectl.kubernetes.io/last-applied-configuration` — co tam jest i czemu to się zmienia?
4. Maks. rozmiar annotation? Co z bardzo dużymi metadata?

## Linki
- [Annotations docs](https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/)
- [Well-known annotations (K8s + ekosystem)](https://kubernetes.io/docs/reference/labels-annotations-taints/)
