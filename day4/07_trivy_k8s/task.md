# Zadanie

1. Zainstaluj **Trivy Operator** w namespace `trivy-system` (Helm: `aqua/trivy-operator`).
2. Zaaplikuj `vulnerable-app.yaml` (celowo podatna aplikacja).
3. Po 1-3 minutach sprawdź `vulnerabilityreports` we wszystkich namespace - powinny pojawić się raporty per kontener.
4. Wypisz raporty z liczbą CVE krytycznych i wysokich (przydatne `jsonpath` na `report.summary`).
5. Sprawdź również `configauditreports`, `rbacassessmentreports`, `exposedsecretreports` - co znajduje Trivy poza CVE?
6. Odpowiedz: dlaczego wystarczy skanowanie obrazów w CI? (Pytanie podchwytliwe - co z nowymi CVE wykrytymi *po* deployu?)
