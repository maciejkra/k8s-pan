# 01 — Service: ekspozycja Pod (NodePort, ClusterIP)

## Cel
Wystawić Pod jako Service — najpierw imperatywnie (`kubectl expose`), potem deklaratywnie (manifest YAML). Zrozumieć działanie DNS w klastrze.

## Kontekst
Pod ma efemeryczny IP — restart = nowy IP. **Service** to stabilny abstrakt: ClusterIP (domyślny, dostępny tylko wewnątrz klastra) lub NodePort (otwiera port na każdym node).

Każdy Service dostaje **DNS** w postaci `<service-name>.<namespace>.svc.cluster.local`. CoreDNS (jeden z Pod-ów w `kube-system`) odpowiada na DNS queries z Podów.

## Prereqs
- Klaster z uruchomionym `myapp-pod` (z poprzednich ćwiczeń lub `kubectl run myapp-pod --image=nginx`)

## Zadanie

### Imperatywnie

1. Wystaw Pod jako NodePort:
   ```bash
   kubectl expose pod myapp-pod --type=NodePort --port=80
   kubectl get service
   ```

2. Otwórz w browserze: `<IP-worker-node>:<NodePort>` (NodePort widoczny w `kubectl get svc`).

### Deklaratywnie

1. Zaaplikuj `service.yaml`:
   ```bash
   kubectl apply -f service.yaml
   ```

2. Test od wewnątrz klastra (DNS):
   ```bash
   kubectl exec -ti myapp-pod -- curl my-app-service
   kubectl exec -ti myapp-pod -- curl my-app-service.default.svc.cluster.local
   ```

3. Sprawdź `/etc/resolv.conf` w Pod — co tam jest?
   ```bash
   kubectl exec -ti myapp-pod -- cat /etc/resolv.conf
   # search default.svc.cluster.local svc.cluster.local cluster.local
   # nameserver 10.43.0.10  (CoreDNS service IP)
   ```

## Pytania kontrolne
1. ClusterIP vs NodePort vs LoadBalancer — kiedy które?
2. Co się stanie gdy Pod stracił label dopasowujący do Service `selector`?
3. `search` w resolv.conf — dlaczego pozwala używać krótkiej nazwy `my-app-service` zamiast pełnego DNS?
4. Co to jest `headless service` (`clusterIP: None`) i kiedy się przydaje? (Hint: StatefulSet w D2/08)

## Linki
- [Service docs](https://kubernetes.io/docs/concepts/services-networking/service/)
- [DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
