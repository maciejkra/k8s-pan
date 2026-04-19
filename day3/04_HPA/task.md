# Zadanie

1. Zaaplikuj manifesty z katalogu (Deployment `php-apache` + Service + HPA). Sprawdź stan HPA - na początku metryka powinna być `<unknown>`, później pojawi się wartość CPU.
2. Wygeneruj load - uruchom Pod `busybox` w pętli wykonujący `wget` do Service `php-apache`.
3. W drugim terminalu obserwuj `kubectl get hpa --watch` oraz `kubectl get pods --watch`. Po jakim czasie i do ilu replik HPA przeskaluje aplikację?
4. Zatrzymaj generator load i poczekaj ~5 minut. Co się dzieje z liczbą replik? Dlaczego scale-down jest wolniejszy niż scale-up?
5. Wytłumacz wzór HPA: `desiredReplicas = currentReplicas * (currentMetric / desiredMetric)`.
