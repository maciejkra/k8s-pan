# 03 — Volumes, PV, PVC, StorageClass, Reclaim Policy

## Cel
Opanować pełen stack storage w K8s: od prostego `emptyDir` po dynamiczne provisioning przez StorageClass.

## Kontekst
Pod jest efemeryczny — bez wolumenów dane giną po restarcie. K8s oferuje kilka poziomów abstrakcji:

| Warstwa | Co to jest | Kiedy |
|---|---|---|
| **emptyDir** | temp per Pod (RAM lub disk) | cache, scratch space, shared między kontenerami w Pod |
| **hostPath** | katalog z node'a | debug, logs collection — NIE produkcja |
| **PersistentVolume (PV)** | klaster-level storage resource | admin pre-provisioning |
| **PersistentVolumeClaim (PVC)** | żądanie Pod-a o storage | user-facing abstraction |
| **StorageClass** | template dynamicznego tworzenia PV | cloud managed, CSI |

**Reclaim Policy** = co zrobić z PV po usunięciu PVC:
- `Retain` — dane zostają, wymagają ręcznego cleanup (bezpieczne dla produkcji)
- `Recycle` (deprecated) — wyczyszczenie i reużycie
- `Delete` — automatic delete (typowe dla cloud dynamic provisioning)

## Plan ćwiczeń (podkatalogi)

1. [`1-volumes-basic/`](./1-volumes-basic/) — emptyDir, hostPath, subPath
2. [`2-volumes-pv-pvc/`](./2-volumes-pv-pvc/) — ręczny PV + PVC + Deployment
3. [`3-volumes-reclaim-policy/`](./3-volumes-reclaim-policy/) — Retain / Recycle / Delete
4. [`4-volumes-sc/`](./4-volumes-sc/) — StorageClass (dynamic provisioning)

## Wyzwanie (task)

Do istniejącego projektu python-redis dodaj volume dla redis (`/data`) używając StorageClass.

1. Uruchom wszystkie manifesty:
   ```bash
   curl <ip>:<port>/api/v1/info
   curl -XPOST <ip>:<port>/api/v1/info
   curl <ip>:<port>/api/v1/info
   ```

2. Usuń redis deployment i dodaj ponownie — counter powinien pokazywać starą wartość (storage jest persistent).

## Pytania kontrolne
1. emptyDir.medium: Memory vs default — różnica w wydajności i rozliczeniu RAM?
2. hostPath — dlaczego NIE w produkcji? (Hint: Pod może przejść na inny node)
3. `accessModes: ReadWriteOnce` vs `ReadWriteMany` — które CSI wspiera RWX?
4. Reclaim `Retain` w produkcji — jak uniknąć wycieku orphaned PV?

## Linki
- [Volumes](https://kubernetes.io/docs/concepts/storage/volumes/)
- [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [Storage Classes](https://kubernetes.io/docs/concepts/storage/storage-classes/)
