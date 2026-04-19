# Zadanie

Do **deploymentu Python+Redis** (z `D1/10`) dodaj **persistent volume** dla Redis (mount w `/data`) używając **StorageClass**.

1. Wdroż i sprawdź, że licznik działa:
   - `GET /api/v1/info` — przeczytaj wartość
   - `POST /api/v1/info` — zwiększ licznik
   - `GET /api/v1/info` — zobacz nową wartość
2. **Usuń** deployment Redis (`kubectl delete deploy redis`) i wdróż go od nowa.
3. Sprawdź licznik — **powinien zachować ostatnią wartość**. Dlaczego?

**Pytanie:** co by się stało, gdyby Redis był wdrożony jako StatefulSet (D2/08) z `volumeClaimTemplates`?

## Podćwiczenia bazowe

Jeśli to twój pierwszy raz z volume w K8s — przejdź najpierw przez:

1. `1-volumes-basic/` — Pod z `emptyDir`, `hostPath`, `subPath`. Gdzie żyją dane po restarcie Pod-a?
2. `2-volumes-pv-pvc/` — manualne `PersistentVolume` + `PersistentVolumeClaim` + Deployment używający PVC.
3. `3-volumes-reclaim-policy/` — przetestuj `Retain`, `Recycle`, `Delete`. Co dzieje się z PV po usunięciu PVC?
4. `4-volumes-sc/` — StorageClass i **dynamic provisioning** — PV powstaje automatycznie.
