# 1 — Basic Volumes: emptyDir, hostPath, subPath

## Cel
Poznać najprostsze typy volumes: tymczasowy (`emptyDir`), node-local (`hostPath`) oraz mechanizm `subPath` do mount konkretnego podkatalogu.

## Kontekst
- **emptyDir** — pusty katalog tworzony przy starcie Pod-a, ginący przy zniknięciu Pod-a. Dwa warianty: na dysku lub `medium: Memory` (tmpfs).
- **hostPath** — bezpośredni katalog z node'a. **Tylko dev/debug** — Pod przeniesiony na inny node widzi inne dane (lub ich brak).
- **subPath** — montuje konkretny plik/podkatalog z volumu, a nie cały volume. Przydatne dla ConfigMap gdzie chcesz tylko jeden klucz.

## Prereqs
- K3d/Kind cluster

## Zadanie

1. emptyDir Pod:
   ```bash
   kubectl apply -f empty-dir-pod.yaml
   kubectl exec emptydir-pod -- ls /cache
   ```

2. hostPath Pod:
   ```bash
   kubectl apply -f host-path-pod.yaml
   kubectl exec hostpath-pod -- ls /host
   # Widać zawartość z node'a
   ```

3. subPath z overwrite:
   ```bash
   kubectl apply -f sub-path-overwrite-pod.yaml
   ```

4. subPath bez overwrite:
   ```bash
   kubectl apply -f sub-path-wo-overwrite-pod.yaml
   ```

## Pytania kontrolne
1. emptyDir + multi-container Pod — czy kontenery dzielą pliki? (cross-link D1/13)
2. hostPath a `readOnly: true` — czy wystarczy do hardeningu?
3. subPath — typowe use case z ConfigMap?
4. Co się stanie gdy Pod zostanie przełożony na inny node (rescheduling) przy hostPath?

## Linki
- [Volumes — emptyDir](https://kubernetes.io/docs/concepts/storage/volumes/#emptydir)
- [Volumes — hostPath](https://kubernetes.io/docs/concepts/storage/volumes/#hostpath)
- [Using subPath](https://kubernetes.io/docs/concepts/storage/volumes/#using-subpath)
