# Solution — 03_resource_quota

## Odpowiedzi

### ResourceQuota vs LimitRange: czemu oba?

**Sole ResourceQuota** dla `requests.cpu`/`limits.cpu` ma pułapkę:

```bash
# NS ma tylko ResourceQuota (brak LimitRange)
kubectl run nginx --image=nginx  # bez --requests/--limits
# Error: pods "nginx" is forbidden: failed quota: team-quota:
#        must specify requests.cpu,requests.memory,limits.cpu,limits.memory
```

Bo Quota **wymaga** jawnych requests/limits, żeby móc policzyć. LimitRange wstrzykuje defaulty — Pod jest "auto-policzony" do Quota. Razem: user może leniwie deploy, admin dostaje egzekwowane budżety.

### Pod z requests=50m, LimitRange min=100m

Pod odrzucony przez admission:
```
Error: maximum cpu usage per Container is 1, but limit is 2
```

Admission działa **zanim** ResourceQuota zacznie liczyć. Kolejność:
1. PodSecurityAdmission (D4/02)
2. LimitRange (min/max)
3. ResourceQuota (suma budżetu)
4. ValidatingAdmissionPolicy (D4/03)

### ResourceQuota + PriorityClass scope

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: high-priority-quota
spec:
  hard:
    pods: "5"
  scopeSelector:
    matchExpressions:
      - scopeName: PriorityClass
        operator: In
        values: [high, critical]
```

Ta Quota liczy tylko Pody z priorityClassName in [high, critical]. Użycie: ograniczasz ile "important" Pod-ów team może zrobić (żeby nie wszystko było critical).

Inne scope: `BestEffort`, `NotBestEffort`, `Terminating`, `NotTerminating`, `CrossNamespacePodAffinity`.

### Object counts — kiedy użyć

Najczęściej:
- **`pods`** — chroni przed "fork bomb" w Deployment (replicas=1000). Default dobry limit: 20-50 per team-NS.
- **`services.loadbalancers`** — każdy LB w cloud kosztuje $ (AWS ALB ~$20/mo). Limit 2-3 na NS.
- **`persistentvolumeclaims`** — zapobiega "każdy dev chce PVC". Limit 5-10.
- **`secrets`** / **`configmaps`** — rzadziej, tylko gdy masz problem ze skalowalnością etcd.
- **`ingresses`** / **`gatewayapi.networking.k8s.io/httproutes`** — kontrola nad publicznymi endpointami.

### Services.loadbalancers w cloud

Każdy `type: LoadBalancer` Service = cloud LB (ELB/ALB/NLB w AWS, Forwarding Rule w GCP, Load Balancer w Azure). Koszty:
- AWS NLB: ~$16/mo + $0.006/LCU
- GCP Regional LB: $0.025/forwarding rule/hr = ~$18/mo
- Azure Standard LB: $0.025/rule/hr = ~$18/mo

Ograniczenie quota na 1-2 LB per NS = max $40/mo per team. Bez quota team może przypadkiem zrobić 10 LB = $200/mo + nikt tego nie zauważa aż FinOps review.

## Walidacja

```bash
kubectl apply -f ns-quota.yaml
kubectl describe resourcequota team-quota -n test-1
# Resource         Used  Hard
# pods             0     10
# requests.cpu     0     2
# ...

kubectl apply -f deployment.yaml
kubectl wait --for=condition=ready pod -n test-1 -l app=demo --timeout=30s

# LimitRange injection
kubectl get pod -n test-1 -l app=demo -o jsonpath='{.items[0].spec.containers[0].resources}' | jq
# {
#   "limits": { "cpu": "200m", "memory": "256Mi" },
#   "requests": { "cpu": "100m", "memory": "128Mi" }
# }

# Scale do limitu
kubectl scale deploy demo -n test-1 --replicas=10
sleep 5
kubectl describe resourcequota team-quota -n test-1 | grep -A 1 pods
# pods   10    10

# Przekroczenie
kubectl scale deploy demo -n test-1 --replicas=15
sleep 3
kubectl get pods -n test-1 -l app=demo --no-headers | wc -l
# 10 (quota zablokowała nadmiar)
kubectl describe rs -n test-1 -l app=demo | grep -A 3 "Events" | head -10
# Events: forbidden: exceeded quota: team-quota, requested: pods=1, used: pods=10, limited: pods=10
```

## Troubleshooting

### ReplicaSet nie tworzy Pod-ów, ale nie ma błędu na Deployment

Deployment jest OK, bo to kontroler wyższego poziomu. Błąd jest na **ReplicaSet**:
```bash
kubectl describe rs -n <ns> -l app=<app>
```
Zobacz `Events:` — tam będzie `exceeded quota`.

### LimitRange wstrzyka ale Pod nadal odrzucony przez Quota

Prawdopodobnie `defaultRequest` jest za duży — suma `replicas × defaultRequest.cpu` przekracza `requests.cpu` quota. Fix: zmniejsz default albo zwiększ quota.

### Quota nie liczy terminating Pod-ów

Quota z `scope: NotTerminating` wyklucza Pody w stanie Terminating (grace period). Domyślny scope liczy wszystko. Pamiętaj o tym przy rolling updatach — chwilowo 2× replicas.

## Cross-link

- D3/02/01 (QoS) — jakie klasy dostają Pody po injection LimitRange
- D3/02/02 (LimitRange details) — więcej o min/max i typach
- D3/07 (PriorityClass) — scopeSelector quota per priorityClass
- D4/03 (VAP) — CEL-based alternatywa gdy Quota/LimitRange za sztywne
