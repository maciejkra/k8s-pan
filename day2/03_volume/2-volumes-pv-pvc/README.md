# 2 — PersistentVolume + PersistentVolumeClaim (manual)

## Cel
Stworzyć ręcznie PV (admin-side resource) + PVC (user-side claim) + Deployment używający volume. Zrozumieć **bind** PV ↔ PVC.

## Kontekst
**PV** (PersistentVolume) = "kawałek" storage w klastrze, opisany przez admina (lub provisioner). Niezależny od Pod-a — przeżyje delete Poda.

**PVC** (PersistentVolumeClaim) = żądanie storage z user-side. Specyfikuje rozmiar i accessModes. K8s **bindujeo** PVC do najmniejszego pasującego PV.

**Deployment** używa PVC przez `volumes.persistentVolumeClaim.claimName`.

W produkcji PV są zazwyczaj tworzone **dynamicznie** przez StorageClass (D2/03/4-volumes-sc) — nie ręcznie.

## Prereqs
- K3d/Kind cluster

## Zadanie

1. Stwórz PV (admin):
   ```bash
   kubectl apply -f pv.yaml
   kubectl get pv
   # STATUS: Available
   ```

2. Stwórz PVC (user):
   ```bash
   kubectl apply -f pvc.yaml
   kubectl get pvc
   # STATUS: Bound (do PV powyżej)
   ```

3. Stwórz Deployment używający PVC:
   ```bash
   kubectl apply -f deploy.yaml
   kubectl get pods -o wide
   ```

4. Zapisz coś do volume:
   ```bash
   POD=$(kubectl get pods -l app=<name> -o jsonpath='{.items[0].metadata.name}')
   kubectl exec "$POD" -- sh -c 'echo persistent > /data/test.txt'
   ```

5. Usuń Pod, odczekaj na restart przez Deployment:
   ```bash
   kubectl delete pod "$POD"
   POD2=$(kubectl get pods -l app=<name> -o jsonpath='{.items[0].metadata.name}')
   kubectl exec "$POD2" -- cat /data/test.txt
   # "persistent" — dane przeżyły!
   ```

## Pytania kontrolne
1. accessModes `ReadWriteOnce` — co znaczy "Once"? (Hint: jeden node)
2. Co się stanie gdy stworzysz PVC większy niż jakikolwiek PV?
3. PV ma `storageClassName: ""` — co znaczy?
4. Po `delete pvc` — czy PV znika? (Hint: zależy od reclaim policy — D2/03/3)

## Linki
- [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [Volumes overview](https://kubernetes.io/docs/concepts/storage/volumes/)
