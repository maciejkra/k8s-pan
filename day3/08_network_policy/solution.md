# Solution — 08_network_policy

## Odpowiedzi

### Dlaczego default-deny zabija DNS

CoreDNS (kube-system/kube-dns) słucha na porcie 53 UDP/TCP, ale z perspektywy Pod-a aplikacja musi **wysłać pakiet** do kube-dns. Default-deny z `policyTypes: [Egress]` i pustą listą `egress: []` blokuje wszystko, łącznie z UDP/53 do kube-dns.

Symptom: `wget example.com` → "bad address" / timeout. `wget` po IP (np. `1.1.1.1`) też timeout, ale z innego powodu.

Fix (podstawowy):
```yaml
egress:
  - to:
      - namespaceSelector: { matchLabels: { kubernetes.io/metadata.name: kube-system } }
        podSelector: { matchLabels: { k8s-app: kube-dns } }
    ports:
      - port: 53
        protocol: UDP
      - port: 53
        protocol: TCP
```

**Ważne**: `kubernetes.io/metadata.name` label jest auto-dodany do NS przez kube-apiserver (od K8s 1.21+). Nie musisz go tworzyć ręcznie.

### Ingress vs Egress

Z punktu widzenia Pod-a którego dotyczy policy:
- **Ingress** = ruch **do** Pod-a (kto może się do mnie łączyć?). `from` = źródło.
- **Egress** = ruch **z** Pod-a (gdzie mogę się łączyć?). `to` = cel.

Pod ma oba: ingress limituje kto może do mnie wejść, egress limituje gdzie mogę wyjść. Dwa zupełnie niezależne zestawy reguł.

Client-server w NP:
- Chcesz "klient może się łączyć z serwerem": **egress allow na kliencie** ORAZ **ingress allow na serwerze**. Oba, bo NP są cumulative (jeden zakazany = pakiet nie idzie).

### `policyTypes` — kiedy pominąć

```yaml
policyTypes: [Ingress]    # bez Egress listed
```

Bez `Egress` w policyTypes — policy NIE zmienia ruchu egress. Jeśli w innym manifeście nie ma default-deny egress, Pod nadal może wychodzić gdziekolwiek.

Reguła: **`policyTypes` enumeruje co policy KONTROLUJE**. Brak w liście = no-op dla tego kierunku.

Default: K8s inferuje `policyTypes` z obecności `ingress`/`egress` w spec. Ale dla czytelności — zawsze pisz explicit.

### Stateful NP — jak w iptables

NP są stateful dzięki **conntrack** (connection tracking) w kernelu:
- Pakiet outbound → conntrack zapamiętuje `(src-ip, src-port, dst-ip, dst-port, protocol)` jako "ESTABLISHED"
- Pakiet inbound matching tej krotki → auto-allowed (state match ESTABLISHED,RELATED)

W iptables ręcznie:
```
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -i eth0 -p tcp --dport 80 -j ACCEPT  # tylko nowe inicjacje
```

CNI (Calico/Cilium) robi to za Ciebie — NP mówi tylko o NOWYCH connection initiation.

### L7 rules w CiliumNetworkPolicy

Standard NP jest **L3/L4** (IP + port). L7 (URL path, HTTP method, gRPC service) wymaga:
1. **Terminacja TLS** — aby zobaczyć URL path, CNI musi widzieć plaintext.
2. **Inspekcja pakietu per request** — drogie wydajnościowo, nie każdy CNI to wspiera.
3. **Spec owijania L7** — rozszerzenia poza core K8s spec.

Cilium robi to przez eBPF + Envoy sidecar (opcjonalnie). Standard NP zostawia L7 dla service meshe (Istio, Linkerd).

Przykład CiliumNetworkPolicy L7:
```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
spec:
  endpointSelector: { matchLabels: { app: api } }
  ingress:
    - fromEndpoints:
        - matchLabels: { app: web }
      toPorts:
        - ports: [ { port: "8080", protocol: TCP } ]
          rules:
            http:
              - method: "GET"
                path: "/api/public/.*"
```

## Walidacja

```bash
kubectl apply -f test-pods.yaml
kubectl wait --for=condition=ready pod/client pod/server --timeout=30s

# Baseline
kubectl exec client -- wget -qO- --timeout=2 server
# <!DOCTYPE html> ... (OK)

# Default-deny
kubectl apply -f deny.network.policy.yaml
kubectl exec client -- wget -qO- --timeout=5 server
# Timeout (zablokowane)

# Selective allow
kubectl apply -f allow-frontend-backend.yaml
kubectl exec client -- wget -qO- --timeout=5 server
# <!DOCTYPE html> ... znowu działa (tier=frontend → tier=backend allowed)
```

## Troubleshooting

### Policy aplikowana ale ruch nadal idzie

```bash
# 1. Sprawdź CNI
kubectl get pods -n kube-system | grep -Ei 'flannel|cilium|calico|kindnet'
```
Flannel → nie wspiera NP. Fix: reinstall klaster z Cilium/Calico.

### Pod w NS ma policy ale NS obok (inny namespace) też ma matching label — ruch dalej blokowany

NetworkPolicy jest **per-namespace**. Policy w NS A NIE kontroluje ruchu w NS B. Jeśli chcesz cross-NS — użyj `namespaceSelector` w `from`.

### DNS działa, ale query do zewnętrznego hosta fail

Odblokowałeś DNS ale nie docelowy host. NP wymaga explicit `to` dla każdego endpointu egress. Albo dodaj allow dla IP range, albo:
```yaml
egress:
  - to:
      - ipBlock:
          cidr: 0.0.0.0/0
          except:
            - 169.254.169.254/32   # blokuj cloud metadata (AWS/GCP IMDS)
```

### `kubectl exec client -- wget example.com` — "bad address"

To jest **DNS failure**. Sprawdź:
```bash
kubectl exec client -- nslookup example.com
# Jeśli "connection timed out; no servers could be reached" — DNS NP block
```

## Cross-link

- D2/07 (Gateway API) — ingress dla ruchu z internetu; NP reguluje wewnętrzny east-west
- D4/09 (OPA/Gatekeeper) — policy że KAŻDY Pod musi mieć NetworkPolicy (enforcement)
- D5/02 (Monitoring) — alerty na policy violations (Cilium Hubble, Calico Flow Logs)
- Presentation slajd 53 (Service Mesh) — Istio/Linkerd robią L7 policy + mTLS; NP to L3/L4
