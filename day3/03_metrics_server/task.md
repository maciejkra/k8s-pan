# Zadanie

1. Sprawdź, czy `metrics-server` działa w namespace `kube-system`. Jeśli nie - zainstaluj.
2. Dla K3d / Kind dodaj do deploymentu `metrics-server` flagi `--kubelet-insecure-tls` oraz `--kubelet-preferred-address-types=InternalIP` (kubelet ma self-signed cert).
3. Poczekaj aż deployment będzie `Available`.
4. Wykonaj `kubectl top nodes` oraz `kubectl top pods -A` - powinieneś widzieć użycie CPU/RAM.
5. Odpowiedz: dlaczego `metrics-server` jest wymagany do działania HPA?
