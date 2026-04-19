# 3 — Reclaim Policy (Retain, Recycle, Delete)

## Cel
Zrozumieć co dzieje się z PV po usunięciu PVC — trzy warianty polityki.

## Kontekst
**`Retain`** — PV nie jest usuwany ani czyszczony. Wymaga ręcznej interwencji admina przed reużyciem. **Bezpieczne** dla produkcji — nie tracimy danych przypadkiem.

**`Recycle`** — **DEPRECATED**. Wolumen był czyszczony (`rm -rf /volume/*`) i gotowy do reużycia. Usunięty z K8s 1.11+.

**`Delete`** — PV i underlying storage (EBS volume, GCE disk, etc.) są **automatycznie usuwane**. Wygodne dla ephemeral workload, niebezpieczne dla produkcji.

Konfiguracja: `persistentVolumeReclaimPolicy: Retain` w PV spec lub `reclaimPolicy: Retain` w StorageClass.

## Prereqs
- K3d/Kind cluster

## Podkatalogi

- [`retain/`](./retain/) — `Retain` policy
- [`delete/`](./delete/) — `Delete` policy
- [`recycle/`](./recycle/) — `Recycle` policy (deprecated, tylko historyczne)

## Zadanie

1. Stwórz PV z Retain policy:
   ```bash
   kubectl apply -f retain/
   kubectl get pv
   ```

2. Usuń PVC:
   ```bash
   kubectl delete pvc <name>
   kubectl get pv
   # PV nadal jest, STATUS: Released
   ```

3. Spróbuj reużyć PV (Released → Available wymaga edytowania `.spec.claimRef`):
   ```bash
   kubectl patch pv <name> -p '{"spec":{"claimRef":null}}'
   # PV teraz Available, można claim'ować
   ```

4. Porównaj z Delete policy:
   ```bash
   kubectl apply -f delete/
   kubectl delete pvc <name>
   kubectl get pv
   # PV zniknął automatycznie (wraz z podkładowym storage)
   ```

## Pytania kontrolne
1. Dlaczego `Recycle` został zdeprekowany? (Hint: security, tylko 1 provisioner)
2. Kiedy `Delete` jest OK? (Hint: ephemeral workloads, stateless caching)
3. Co zrobić gdy PVC uszkodzone a chcesz dane z PV? (Hint: tworzenie nowego PVC z identycznym `claimRef`)
4. StorageClass reclaim policy vs PV reclaim policy — kto wygrywa?

## Linki
- [Reclaiming](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#reclaiming)
- [Lifecycle of a volume and claim](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#lifecycle-of-a-volume-and-claim)
