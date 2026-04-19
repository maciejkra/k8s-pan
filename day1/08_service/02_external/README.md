# 02 — External Services i Endpoints

## Cel
Wystawić zewnętrzny serwis (poza klastrem) jako Service w klastrze — żeby aplikacje mogły go używać przez wewnętrzny DNS.

## Kontekst
Czasem aplikacja w klastrze potrzebuje **wewnętrznej nazwy DNS** dla zewnętrznego serwisu (zewnętrzna baza danych, third-party API). Dwa podejścia:
1. **ExternalName Service** — DNS alias (`google-service` → `www.google.com`)
2. **Service bez selectora + ręczne Endpoints** — gdy zewnętrzny serwis ma znany IP

Endpoints to wewnętrzny K8s obiekt mapujący Service → konkretne IP+porty. Normalnie tworzony automatycznie przez kontroler na podstawie `selector`. Bez selectora — można utworzyć manualnie.

## Prereqs
- K3d/Kind cluster z `myapp-pod`

## Zadanie

### ExternalName

1. Wdroż:
   ```bash
   kubectl apply -f google-service.yaml
   kubectl exec -ti myapp-pod -- curl google-service
   # CoreDNS zwraca CNAME → www.google.com
   ```

### Endpoints manualne

1. Stwórz Service bez selectora:
   ```bash
   kubectl apply -f external-service.yaml
   kubectl get svc
   kubectl get endpoints
   ```

### Domyślne ENV variables Pod-a

Każdy Pod dostaje env vars dla wszystkich Service w tym samym namespace istniejących **przed** jego startem. Format (dla Service `redis-master`):
- `REDIS_MASTER_SERVICE_HOST=10.0.0.11`
- `REDIS_MASTER_SERVICE_PORT=6379`
- `REDIS_MASTER_PORT=tcp://10.0.0.11:6379`
- `REDIS_MASTER_PORT_6379_TCP_PROTO=tcp`

Sprawdź w pod-zie:
```bash
kubectl exec -ti myapp-pod -- env | grep _SERVICE_
```

## Pytania kontrolne
1. ExternalName vs CNAME w DNS — gdzie różnica?
2. Co się stanie z env vars gdy Service powstaje **po** Pod-zie?
3. Kiedy używać Service bez selectora? (Hint: legacy DB poza klastrem)
4. Dlaczego K8s rekomenduje DNS zamiast env vars dla service discovery?

## Linki
- [Services without selectors](https://kubernetes.io/docs/concepts/services-networking/service/#services-without-selectors)
- [ExternalName Service](https://kubernetes.io/docs/concepts/services-networking/service/#externalname)
