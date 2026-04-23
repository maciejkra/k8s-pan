# Prezentacja — errata

Ten dokument zawiera poprawki dla `k8s-training-2026.pdf` (62 slajdy). Zidentyfikowane przez deep-review repo kwiecień 2026.

Jeżeli masz dostęp do źródła pptxgenjs — zastosuj te zmiany tam i wygeneruj nowy PDF. W przeciwnym razie linkuj ten plik z root README jako "known corrections".

---

## Slajd 28 — RBAC ("Test bez wykonywania:")

**Problem**: slajd kończy się frazą `Test bez wykonywania:` i pozostawia obrazu trzy ramki bez treści. Powinny pokazywać komendy `kubectl auth can-i`.

**Brakujący content** (dodać po `Test bez wykonywania:`):

```text
$ kubectl auth can-i create pods --as=alice -n prod
yes

$ kubectl auth can-i delete secrets --as=bob -n kube-system
no

$ kubectl auth can-i --list --as=alice -n prod
Resources                       Verbs
pods                            [create get list]
configmaps                      [get list]
...
```

Dopisek pod blokiem: `--as <user>` — impersonacja (wymaga prawa `impersonate` w RBAC); bez `--as` sprawdza aktualnego usera.

Cross-link do ćwiczenia: **D2/06 AuthN/AuthZ** — tam pełen walkthrough SA token → x509 cert → OIDC → RBAC.

---

## Slajd 36 — HPA ("Wymóg:  (D3/03)")

**Problem**: po słowie `Wymóg:` brak treści przed `(D3/03)`. Powinno wymieniać Metrics Server.

**Poprawka**: zamienić `Wymóg:  (D3/03)` na:

```text
Wymóg: Metrics Server (D3/03)
```

Dodatkowo można dopisać w kontekście: "HPA bez działającego metrics-server pokazuje `<unknown>/50%` w kolumnie TARGETS i nie skaluje".

---

## Drobne sugestie (opcjonalne)

- **Slajd 34 (StatefulSet)**: jeśli pojawia się tabelka Deployment vs StatefulSet z kolumną "Pod IP", uwaga: **Pod IP NIE jest stabilny** ani w Deployment, ani w StatefulSet. Stabilny jest **DNS hostname per Pod** (`pod-N.service.ns.svc.cluster.local`). Poprawny wiersz: "Network identity | tylko Service DNS | **stabilny DNS hostname per Pod**".
- **Slajd 50 (Falco)**: `driver.kind=ebpf` (legacy) → rekomendować `modern_ebpf` (CO-RE, BTF) jako default na klastrach ≥K8s 1.25 i kernel ≥5.8.
- **Slajd 47 (Vault)**: chart wersja jeśli wspomniana → `0.30+` (nie `0.24`).
- **Slajd 60 (kubeadm)**: jeśli wspomniane wersje:
  - k8s: `v1.34.0` (2026 stabilny)
  - kube-vip: `v1.0.4` (styczeń 2026)
  - Cilium: `1.17.x`
  - **Rekomendowana metoda kube-vip: static pod** (nie DaemonSet — zobacz D5/03 dla wyjaśnienia kolejności startu).

---

## Proces aktualizacji

Jeśli masz `pptxgenjs` source repo w innym miejscu:

1. Edytuj odpowiednie slajdy.
2. `npm run build` (lub jak generujesz) → nowy PDF.
3. Commit PDF do repo: `docs/k8s-training-2026.pdf` (lub link via release).
4. Usuń odpowiednie sekcje z tej erraty.

Jeśli nie masz source — zostaw ten plik jako oficjalną listę korrekt, zlinkowaną z main README.
