# Zadanie

1. Wypisz listę istniejących namespace.
2. Stwórz nowy namespace `workshops`.
3. Zaaplikuj deployment `python-app` w namespace `workshops` i wypisz wszystkie zasoby z tego namespace.
4. Ustaw `workshops` jako default dla bieżącego kontekstu - zweryfikuj, że `kubectl get pods` (bez `-n`) pokazuje Pody z `workshops`. Następnie wróć do `default`.

