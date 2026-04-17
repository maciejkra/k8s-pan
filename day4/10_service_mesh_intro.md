# 10 — Service Mesh: wprowadzenie (teoria)

> **Bez ćwiczeń praktycznych.** Service mesh to duża, osobna domena — w 5-dniowym kursie omawiamy tylko koncept i kryteria wyboru.

## Co to jest service mesh?

Warstwa infrastruktury **transparentnie** dodająca do komunikacji service-to-service:
- **mTLS** — szyfrowanie + uwierzytelnianie wzajemne między serwisami
- **traffic management** — canary, blue-green, retries, timeouts, circuit breaker — bez zmian w aplikacji
- **observability** — automatyczne metryki RED (Rate, Errors, Duration) + distributed tracing
- **policy** — kto może rozmawiać z kim na poziomie aplikacyjnym (bardziej granularny niż NetworkPolicy)

Implementacja: każdy Pod dostaje **sidecar proxy** (Envoy) lub używa **eBPF** (Cilium). Cały ruch przechodzi przez proxy, którym zarządza control plane mesh.

## Kiedy wprowadzać service mesh?

✅ **Tak**:
- 50+ mikroserwisów komunikujących się ze sobą
- Wymaganie compliance: encrypted in-transit (HIPAA, PCI)
- Multiple tenants/teams w jednym klastrze (zero-trust networking)
- Potrzeba zero-downtime migration / canary releases bez zmian w aplikacjach
- Multicluster service discovery

❌ **Nie**:
- Mniej niż 10 serwisów
- Monolit + 2-3 satellite services
- Wczesny etap startupu (over-engineering)
- Brak dedicated platform team — service mesh wymaga utrzymania

## Porównanie najpopularniejszych

| | **Istio** | **Linkerd** | **Cilium Service Mesh** |
|---|---|---|---|
| Sidecar | Envoy | linkerd2-proxy (Rust) | eBPF (no sidecar dla L4) + Envoy dla L7 |
| Złożoność | wysoka | niska | średnia (ale wymaga znajomości eBPF) |
| Performance overhead | ~5-10ms p99 | ~1-3ms p99 | minimal (eBPF in-kernel) |
| Funkcje | najbogatsze (egress gateway, EnvoyFilter, WASM) | esencjalne (mTLS + traffic split + obs) | overlap z CNI (jeden tool dla networking + mesh) |
| Lock-in | wysoki (custom resources) | średni | wysoki (wymaga Cilium CNI) |
| Społeczność | największa, CNCF graduated | CNCF graduated, Buoyant commercial | rosnąca, Isovalent commercial |

**Rekomendacje**:
- Pierwszy mesh, mały zespół platformowy → **Linkerd** (operability)
- Bogate use cases (multi-cluster, advanced traffic shaping) → **Istio**
- Już używasz Cilium jako CNI → **Cilium Service Mesh** (bez dodatkowej warstwy)

## Czego NIE robić

- **Nie zaczynaj od mesh** — najpierw rozwiąż observability (D5/04), NetworkPolicy (D3/08), Ingress/Gateway (D2/07). Mesh jest **dodatkową** warstwą.
- **Nie wymuszaj sidecar wszędzie** — stateful workload (bazy), CronJob, Init container często **nie potrzebują** mesh; sidecar dodaje 50-100MB RAM × N replik.
- **Nie próbuj robić wszystkiego z mesh** — autoryzacja biznesowa, walidacja danych = aplikacja, nie sidecar.

## Alternatywy "lżejsze niż mesh"

Gdy potrzeby są mniejsze:
- **mTLS bez mesh**: SPIRE/SPIFFE + cert-manager + side-injection klucza w aplikację
- **Traffic management bez mesh**: Argo Rollouts (canary deployments) + Gateway API (D2/07)
- **Observability bez mesh**: OpenTelemetry SDK w kodzie + Loki/Tempo (D5/04)

## Linki do samodzielnej nauki

- [The Service Mesh Wars are over](https://thenewstack.io/the-service-mesh-wars-are-over/) — perspective po settled landscape
- [Linkerd workshop](https://linkerd.io/2.15/getting-started/) — najszybszy path do hands-on (mesh w 5 min)
- [Istio docs](https://istio.io/latest/docs/) — kompleksowo, dla zaawansowanych
- [eBPF + Cilium](https://docs.cilium.io/en/stable/network/servicemesh/) — alternatywne podejście
