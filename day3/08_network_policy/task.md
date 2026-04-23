# Zadanie

## Część 0 — Sprawdź CNI

```bash
# K3s/K3d — powinieneś mieć Cilium albo Calico (NIE Flannel)
kubectl get pods -n kube-system | grep -Ei 'cilium|calico|flannel'
# Kind — sprawdź czy kindnet ≥ v0.20 (ingress) / v0.26 (egress)
kubectl get pods -n kube-system | grep kindnet
kubectl -n kube-system get daemonset kindnet -o jsonpath='{.spec.template.spec.containers[0].image}'
```

Jeśli masz Flannel — wróć do README banner i przełącz CNI, bez tego dalej nie ma sensu.

## Część 1 — Setup test pods

```bash
kubectl apply -f test-pods.yaml
kubectl wait --for=condition=ready pod/client pod/server --timeout=30s
```

## Część 2 — Weryfikacja initial (bez policy)

```bash
# Klient łączy się z serwerem — OK
kubectl exec client -- wget -qO- --timeout=2 server
# <!DOCTYPE html> ... (nginx welcome)

# Klient łączy się z internetem — OK
kubectl exec client -- wget -qO- --timeout=2 https://example.com | head -c 50
# <!doctype html>...
```

## Część 3 — Default deny all

```bash
kubectl apply -f deny.network.policy.yaml

# Test
kubectl exec client -- wget -qO- --timeout=5 server
# Spodziewane: timeout (Ingress na server zablokowany)

kubectl exec client -- wget -qO- --timeout=5 example.com
# Spodziewane: "bad address" albo timeout (Egress zablokowany, w tym DNS)
```

## Część 4 — Allow frontend → backend

```bash
# Default-deny ZOSTAJE. Dorzucamy selective allow.
kubectl apply -f allow-frontend-backend.yaml

# Test — klient ma tier=frontend, server ma tier=backend
kubectl exec client -- wget -qO- --timeout=5 server
# Spodziewane: nginx HTML (ingress allowed)

kubectl exec client -- wget -qO- --timeout=5 example.com
# Spodziewane: nadal blocked (tylko ingress na server został allowed, egress zabez.)
```

## Część 5 — DNS debugging pattern

```bash
# Cleanup egress rules
kubectl delete -f deny.network.policy.yaml

# Tylko busybox egress deny
kubectl apply -f network-policy.yaml
kubectl exec client -- wget -qO- --timeout=5 server.default
# Spodziewane: timeout (bez DNS lookup nie można rozwiązać "server")

# Dodaj DNS allow
kubectl apply -f network-policy-dns.yaml
kubectl exec client -- wget -qO- --timeout=5 server.default
# DNS resolve OK, ale samo połączenie zablokowane (egress to 80 na backend nadal deny)
# Widać: DNS samo nie wystarczy — potrzebujesz też allow na docelowy service
```

## Część 6 — Cleanup

```bash
kubectl delete -f . --ignore-not-found
kubectl delete pod client server svc server
```

## Pytania

1. Dlaczego `default-deny` zabija DNS? Co CoreDNS potrzebuje żeby Pod mógł z nim gadać?
2. Ingress vs Egress policy — co oznacza "egress" policy na *moim* Podzie? (Hint: kto źródło, kto cel?)
3. `policyTypes: [Ingress, Egress]` — kiedy można pominąć któryś?
4. NetworkPolicy jest stanowa (stateful) — response dla dopuszczonego requesta jest auto-zezwolona. Jak byś to zrobił w iptables ręcznie?
5. **Bonus**: Cilium dodaje CRD `CiliumNetworkPolicy` z L7 rules (URL paths, HTTP methods). Czemu standard NetworkPolicy tego nie ma?

## Walidacja wymagającego CNI

Gdyby nic nie blokowało mimo policy:
```bash
# Upewnij się że CNI enforcer działa
# Cilium:
kubectl -n kube-system exec ds/cilium -- cilium-dbg policy get | head

# Calico:
kubectl -n kube-system exec ds/calico-node -- calicoctl get networkpolicy
```
