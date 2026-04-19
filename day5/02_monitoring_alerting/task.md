# Zadanie

1. Zainstaluj `kube-prometheus-stack` (Helm) w namespace `monitoring` z `values.yaml`.
2. Zrób port-forward do Service Grafany (port 3000). Zaloguj się (`admin` / `prom-operator`) i przejrzyj preinstall'd dashboards (Cluster, Node, Pod, Workload).
3. Wypisz wszystkie `ServiceMonitor` w klastrze - co jest scrapowane?
4. Zainstaluj **Loki** (`grafana/loki-stack`) i dodaj go w Grafanie jako Data Source. Wykonaj parę zapytań LogQL (np. `{namespace="default"} |= "error"`).
5. Stwórz własny `PrometheusRule` z alertem `HighErrorRate` (5xx > 5% przez 5 minut) i sprawdź, czy pojawia się w AlertManagerze.
6. **Bonus**: zaimportuj dashboard `12239` (DCGM) lub `17813` (Trivy) i zobacz, jak wpinają się do Twojego stacka.
