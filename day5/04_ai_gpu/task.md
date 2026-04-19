# Zadanie

1. Zainstaluj **fake-gpu-operator** (Helm OCI: `ghcr.io/run-ai/fake-gpu-operator/fake-gpu-operator`) z topologią z `01_install_fake_gpu/topology.yaml`. Poczekaj, aż `device-plugin` będzie `Ready`.
2. Sprawdź, że node'y eksponują zasób `nvidia.com/gpu` (`describe nodes | grep nvidia`).
3. Zaaplikuj `02_gpu_pod/pod.yaml` (Pod prosząc o 1 GPU). Sprawdź, na którym node wylądował i jakie ma `Limits`.
4. Zaaplikuj `03_multi_gpu_pod/` - Pod z 4 GPU. Czy się zaschedulował?
5. Wykonaj `04_mig_demo/` - rozdziel jedno fizyczne GPU na profile MIG (`1g.5gb`, `3g.20gb`) i wdróż Pod używający `nvidia.com/mig-1g.5gb`.
6. Wymień różnice między **Time-slicing**, **MIG** i **MPS** - kiedy które wybierzesz w produkcji?
