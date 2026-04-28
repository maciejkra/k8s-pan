apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  name: kube-vip
  namespace: kube-system
spec:
  hostNetwork: true
  containers:
    - name: kube-vip
      image: ghcr.io/kube-vip/kube-vip:v1.1.2
      imagePullPolicy: IfNotPresent
      args:
        - manager
      env:
        # Wymusza ścieżkę kubeconfig — bez tego kube-vip v1.x próbuje in-cluster
        # discovery przez `https://kubernetes:6443` (default Go client) i fallbackuje
        # do DNS lookup hostname `kubernetes` zamiast użyć /etc/kubernetes/admin.conf.
        - name: KUBECONFIG
          value: "/etc/kubernetes/admin.conf"
        - name: vip_arp
          value: "true"
        - name: port
          value: "6443"
        - name: vip_nodename
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: vip_interface
          value: ${vip_interface}
        - name: vip_subnet
          value: "32"
        - name: dns_mode
          value: first
        - name: cp_enable
          value: "true"
        - name: cp_namespace
          value: kube-system
        - name: svc_enable
          value: "false"
        - name: vip_leaderelection
          value: "true"
        - name: vip_leasename
          value: plndr-cp-lock
        - name: vip_leaseduration
          value: "5"
        - name: vip_renewdeadline
          value: "3"
        - name: vip_retryperiod
          value: "1"
        - name: address
          value: ${vip_address}
        - name: prometheus_server
          value: :2112
      securityContext:
        capabilities:
          add:
            - NET_ADMIN
            - NET_RAW
          drop:
            - ALL
      resources: {}
      volumeMounts:
        - mountPath: /etc/kubernetes/admin.conf
          name: kubeconfig
  volumes:
    - name: kubeconfig
      hostPath:
        path: /etc/kubernetes/admin.conf
        # type: File (NIE FileOrCreate) — pod nie wstaje aż admin.conf realnie istnieje.
        # FileOrCreate stworzyłby pusty plik gdy kubelet odpala pod przed kubeadm init/join,
        # kube-vip wczytałby pusty kubeconfig → fallback do hostname `kubernetes` → DNS fail.
        type: File
