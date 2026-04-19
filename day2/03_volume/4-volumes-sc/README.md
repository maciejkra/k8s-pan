# 4 — StorageClass (dynamic provisioning)

## Cel
Użyć StorageClass do **dynamicznego** tworzenia PV — bez konieczności ręcznego pre-provisioning.

## Kontekst
Bez StorageClass admin musi **ręcznie** tworzyć PV dla każdego PVC — żmudne i nieskalowalne. StorageClass automatyzuje:
1. User tworzy PVC wskazując `storageClassName`
2. K8s provisioner (CSI plugin) automatycznie tworzy PV + underlying storage (EBS / GCE disk / Azure Disk / NFS / Ceph / Longhorn)
3. PVC jest bound do nowego PV

Każdy cloud provider dostarcza default StorageClass (`gp2` na AWS, `standard` na GCP). K3d/Kind często ma `local-path` (Rancher local-path-provisioner).

## Prereqs
- K3d/Kind cluster

## Zadanie

1. Sprawdź istniejące StorageClass:
   ```bash
   kubectl get sc
   # NAME                  PROVISIONER             RECLAIMPOLICY
   # local-path (default)  rancher.io/local-path   Delete
   ```

2. Stwórz custom StorageClass:
   ```bash
   kubectl apply -f sc.yaml
   ```

3. Stwórz PVC używający tej StorageClass:
   ```bash
   kubectl apply -f pvc.yaml
   kubectl get pvc
   # STATUS: Pending → Bound (po ~kilka s)
   ```

4. Sprawdź auto-utworzony PV:
   ```bash
   kubectl get pv
   # Provisioner sam go stworzył!
   ```

5. Usuń PVC — PV znika wraz z nim (jeśli Reclaim = Delete):
   ```bash
   kubectl delete pvc <name>
   kubectl get pv
   ```

## Pytania kontrolne
1. `volumeBindingMode: Immediate` vs `WaitForFirstConsumer` — kiedy które?
2. Jak ustawić default StorageClass? (Hint: annotation `storageclass.kubernetes.io/is-default-class: "true"`)
3. CSI driver vs in-tree provisioner — dlaczego K8s migruje wszystko na CSI?
4. StorageClass dla workload AI/ML (duże modele) — jakie parametry? (Hint: IOPS, throughput, parallel I/O)

## Linki
- [Storage Classes](https://kubernetes.io/docs/concepts/storage/storage-classes/)
- [Dynamic Volume Provisioning](https://kubernetes.io/docs/concepts/storage/dynamic-provisioning/)
- [CSI drivers](https://kubernetes-csi.github.io/docs/drivers.html)
