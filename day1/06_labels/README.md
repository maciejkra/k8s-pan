# 07 — Labels i selectors

## Cel
Zrozumieć jak labele identyfikują obiekty i jak selektory pozwalają je filtrować. Nauczyć się set-based selectors (in / notin) używanych przez Deployment, ReplicaSet, DaemonSet, StatefulSet, Job.

## Kontekst
**Labels** = klucz-wartość tagi przypisane do obiektów. Identyfikujące — używane przez K8s do matchowania zasobów (Service → Pod, ReplicaSet → Pod, NetworkPolicy → Pod).

**Annotations** (D2/04) — non-identyfikujące metadata, dla narzędzi/ludzi (data wdrożenia, właściciel, link do runbook).

Konwencje labelowania (oficjalne):
- `app.kubernetes.io/name`, `app.kubernetes.io/instance`, `app.kubernetes.io/version`, `app.kubernetes.io/component`, `app.kubernetes.io/part-of`, `app.kubernetes.io/managed-by`

Bez konwencji w 50+ Podach klastra szybko nie wiesz "co należy do czego".

## Prereqs
- K3d/Kind cluster z jakimiś Podami (np. po wdrożeniu z poprzednich ćwiczeń)

## Zadanie

1. Zobacz wszystkie labele:
   ```bash
   kubectl get pods -A --show-labels
   ```

2. Filtruj po pojedynczej etykiecie:
   ```bash
   kubectl get pods -l environment=production,tier=frontend
   ```

3. Set-based selectors (`in`, `notin`):
   ```bash
   kubectl get pods -A -l 'tier in (control-plane)'
   kubectl get pods -A -l 'tier in (control-plane),component notin (kube-scheduler)'
   ```

4. Dodaj label runtime:
   ```bash
   kubectl label pod/myapp-pod test-label=my-label
   kubectl get pods -l test-label=my-label
   kubectl get pods -l 'test-label in (my-label)'
   ```

5. Usuń label (znak `-` na końcu):
   ```bash
   kubectl label pod/myapp-pod test-label-
   ```

## Linki
- [Labels and Selectors](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/)
- [Common labels guidelines](https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/)

## Resources używające set-based selectors
- Job, Deployment, ReplicaSet, DaemonSet, StatefulSet, NetworkPolicy
