# 08 — Network Policy: izolacja sieciowa

## Cel
Zaaplikować **default-deny** NetworkPolicy w namespace, dodać selektywne `allow` dla wybranych Pod-ów. Zaobserwować jak ruch jest blokowany.

## Kontekst
Domyślnie w K8s **wszystkie Pody mogą rozmawiać ze wszystkimi** — brak izolacji. To wystarczy dla małego klastra, ale w multi-tenant lub prod = security risk.

**NetworkPolicy** = manifest definiujący ingress/egress dla Pod-ów (matched przez `podSelector`). Wymaga **CNI z policy support** (Calico, Cilium, Weave). Flannel default — NIE wspiera.

Wzorzec produkcyjny:
1. **default-deny** all ingress (i opcjonalnie egress) per namespace
2. Selektywnie `allow` per komunikacja: `frontend → backend`, `backend → db`, `app → DNS`

Bez `default-deny` wszystkie nowe Pody mają full komunikację — łatwo zapomnieć dodać policy → szczelina security.

## Prereqs
- K3d/Kind cluster z CNI obsługującym NetworkPolicy (K3d default Flannel — może wymagać reinstalacji z Calico)

## Zadanie

1. Sprawdź initial state — komunikacja Pod-Pod działa:
   ```bash
   kubectl exec -ti nginx-stsf-0 -- curl stsf-service.default
   # success
   ```

2. Zaaplikuj default-deny:
   ```bash
   kubectl apply -f deny.network.policy.yaml
   ```

3. Test ponownie:
   ```bash
   kubectl exec -ti nginx-stsf-0 -- curl stsf-service.default
   # timeout — zablokowane
   ```

4. Usuń policy:
   ```bash
   kubectl delete -f deny.network.policy.yaml
   kubectl exec -ti nginx-stsf-0 -- curl stsf-service.default
   # znowu działa
   ```

5. **Praktyka** — selektywne allow:
   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata: { name: allow-frontend-to-backend }
   spec:
     podSelector: { matchLabels: { app: backend } }
     ingress:
       - from:
           - podSelector: { matchLabels: { app: frontend } }
   ```

## Pytania kontrolne
1. NetworkPolicy + Flannel — czemu nie działa? Co zrobić?
2. Pod wewnątrz namespace `prod` — domyślnie może rozmawiać z `kube-system`?
3. Egress NetworkPolicy — kiedy stosować?
4. NetworkPolicy nie wspiera namespace-level rules natywnie — co robić? (Hint: namespaceSelector + labelowanie ns)

## Linki
- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Cluster networking](https://kubernetes.io/docs/concepts/cluster-administration/networking/)
- [Network Policy editor](https://editor.networkpolicy.io)
- [Recipes (ahmetb)](https://github.com/ahmetb/kubernetes-network-policy-recipes)
- [K8s networking deep dive (Sookocheff)](https://sookocheff.com/post/kubernetes/understanding-kubernetes-networking-model/)

## Compare CNI

[Spreadsheet — porównanie CNI providers](https://docs.google.com/spreadsheets/d/1qCOlor16Wp5mHd6MQxB5gUEQILnijyDLIExEpqmee2k/edit#gid=0)

Service Mesh — patrz **D4/10** (markdown teoretyczny).
