# Zadanie

1. Wystaw pod'a z obrazem `krajewskim/python-api:new` jako Service typu `NodePort` tworząc plik z serwisem.
2. Otwórz w przeglądarce `<IP-node>:<NodePort>` i upewnij się, że aplikacja odpowiada.
3. Sprawdź czy działa od wewnątrz klastra przez DNS (`my-app-service` oraz `my-app-service.default.svc.cluster.local`).
4. Sprawdź `/etc/resolv.conf` w Pod-zie - co zawiera linia `search`? Dlaczego pozwala używać krótkiej nazwy Service?
5. Odpowiedz: co się stanie, gdy Pod straci label dopasowujący do `selector` Service?
