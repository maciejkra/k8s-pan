variable "vip_address" {
  description = "VIP kube-vip (na DO demo — VPC blokuje GARP, więc nie programuje routingu)."
  type        = string
  default     = "10.135.0.100"
}

# Klucz szyfrujący Secrets w etcd. Generowany losowo per `terraform apply`.
resource "random_bytes" "enc_key" {
  length = 32
}

# Explicit VPC. KLUCZOWE: bez tego DO przypisuje droplety do legacy network 10.135.x.x,
# którego NIE ma na interfejsie eth0 — kubeadm bind na advertiseAddress nie zadziała.
# Z explicit VPC ipv4_address_private == VPC IP == real eth0 IP.
resource "digitalocean_vpc" "k8s" {
  name     = "k8s-training-vpc"
  region   = "fra1"
  ip_range = "10.135.0.0/20"
}

resource "digitalocean_loadbalancer" "control_plane_lb" {
  name   = "control-plane-lb"
  region = "fra1"

  forwarding_rule {
    entry_protocol  = "tcp"
    entry_port      = 443
    target_protocol = "tcp"
    target_port     = 443
  }

  forwarding_rule {
    entry_protocol  = "tcp"
    entry_port      = 6443
    target_protocol = "tcp"
    target_port     = 6443
  }

  forwarding_rule {
    entry_protocol  = "tcp"
    entry_port      = 80
    target_protocol = "tcp"
    target_port     = 80
  }

  healthcheck {
    protocol                 = "tcp"
    port                     = 6443
    check_interval_seconds   = 5
    response_timeout_seconds = 3
    healthy_threshold        = 3
    unhealthy_threshold      = 3
  }

  droplet_tag = "control-plane"
}

resource "digitalocean_droplet" "cpnode" {
  count    = 3
  name     = "cpnode${count.index + 1}"
  image    = "ubuntu-24-04-x64"
  region   = "fra1"
  size     = "s-2vcpu-4gb"
  tags     = ["control-plane"]
  vpc_uuid = digitalocean_vpc.k8s.id
  ssh_keys = [data.digitalocean_ssh_key.terraform.id]

  provisioner "remote-exec" {
    inline = ["until echo 'Checking if SSH is ready' && exit; do echo 'Waiting for SSH...'; sleep 10; done"]
    connection {
      type        = "ssh"
      host        = self.ipv4_address
      user        = "root"
      private_key = file(var.pvt_key)
      timeout     = "2m"
    }
  }

  provisioner "file" {
    content     = file("../prepare.sh")
    destination = "/root/prepare.sh"
    connection {
      type        = "ssh"
      host        = self.ipv4_address
      user        = "root"
      private_key = file(var.pvt_key)
    }
  }

  # /etc/kubernetes/{,manifests/} przed kubeadm init nie istnieją — tworzymy.
  provisioner "remote-exec" {
    inline = [
      "mkdir -p /etc/kubernetes/manifests",
      "mkdir -p /var/log/kubernetes/audit",
    ]
    connection {
      type        = "ssh"
      host        = self.ipv4_address
      user        = "root"
      private_key = file(var.pvt_key)
    }
  }

  provisioner "file" {
    source      = "../kubernetes/audit-policy.yaml"
    destination = "/etc/kubernetes/audit-policy.yaml"
    connection {
      type        = "ssh"
      host        = self.ipv4_address
      user        = "root"
      private_key = file(var.pvt_key)
    }
  }

  # enc.yaml — klucz losowo wygenerowany per apply, NIE w repo.
  provisioner "file" {
    content = templatefile("${path.module}/enc.yaml.tpl", {
      enc_key = random_bytes.enc_key.base64
    })
    destination = "/etc/kubernetes/enc.yaml"
    connection {
      type        = "ssh"
      host        = self.ipv4_address
      user        = "root"
      private_key = file(var.pvt_key)
    }
  }

  # prepare.sh — containerd + k8s 1.35.3 + sysctl + enable kubelet
  provisioner "remote-exec" {
    inline = ["sleep 15; sudo bash /root/prepare.sh"]
    connection {
      type        = "ssh"
      host        = self.ipv4_address
      user        = "root"
      private_key = file(var.pvt_key)
    }
  }
}

resource "digitalocean_droplet" "knode" {
  count    = 3
  name     = "knode${count.index + 1}"
  image    = "ubuntu-24-04-x64"
  region   = "fra1"
  size     = "s-2vcpu-4gb"
  tags     = ["worker"]
  vpc_uuid = digitalocean_vpc.k8s.id
  ssh_keys = [data.digitalocean_ssh_key.terraform.id]

  provisioner "remote-exec" {
    inline = ["until echo 'Checking if SSH is ready' && exit; do echo 'Waiting for SSH...'; sleep 10; done"]
    connection {
      type        = "ssh"
      host        = self.ipv4_address
      user        = "root"
      private_key = file(var.pvt_key)
      timeout     = "2m"
    }
  }

  provisioner "file" {
    content     = file("../prepare.sh")
    destination = "/root/prepare.sh"
    connection {
      type        = "ssh"
      host        = self.ipv4_address
      user        = "root"
      private_key = file(var.pvt_key)
    }
  }

  provisioner "remote-exec" {
    inline = ["sleep 15; sudo bash /root/prepare.sh"]
    connection {
      type        = "ssh"
      host        = self.ipv4_address
      user        = "root"
      private_key = file(var.pvt_key)
    }
  }
}

# Renderuje kubeadm-config.yaml per CP (advertiseAddress = self VPC IP, certSANs = wszystkie
# publiczne CP IP + LB IP). Po dodaniu vpc_uuid `ipv4_address_private` zwraca real VPC IP.
resource "null_resource" "cp_kubeadm_config" {
  count = 3
  depends_on = [
    digitalocean_droplet.cpnode,
    digitalocean_loadbalancer.control_plane_lb,
  ]

  triggers = {
    advertise = digitalocean_droplet.cpnode[count.index].ipv4_address_private
    lb_ip     = digitalocean_loadbalancer.control_plane_lb.ip
    enc_key   = random_bytes.enc_key.base64
  }

  provisioner "file" {
    content = templatefile("${path.module}/kubeadm-config.yaml.tpl", {
      advertise_address = digitalocean_droplet.cpnode[count.index].ipv4_address_private
      cert_sans = concat(
        digitalocean_droplet.cpnode.*.ipv4_address_private,
        digitalocean_droplet.cpnode.*.ipv4_address,
        [digitalocean_loadbalancer.control_plane_lb.ip],
      )
    })
    destination = "/root/kubeadm-config.yaml"

    connection {
      type        = "ssh"
      host        = digitalocean_droplet.cpnode[count.index].ipv4_address
      user        = "root"
      private_key = file(var.pvt_key)
    }
  }
}

# Renderuje kube-vip-static-pod.yaml WPROST do /etc/kubernetes/manifests/ — kubelet podniesie
# static pod podczas kubeadm init/join. vip_interface=eth0 (DO Ubuntu 24.04 ma tylko eth0).
resource "null_resource" "cp_kube_vip" {
  count      = 3
  depends_on = [digitalocean_droplet.cpnode]

  triggers = {
    cp_id = digitalocean_droplet.cpnode[count.index].id
  }

  provisioner "file" {
    content = templatefile("${path.module}/kube-vip-static-pod.yaml.tpl", {
      vip_interface = "eth0"
      vip_address   = var.vip_address
    })
    destination = "/etc/kubernetes/manifests/kube-vip.yaml"

    connection {
      type        = "ssh"
      host        = digitalocean_droplet.cpnode[count.index].ipv4_address
      user        = "root"
      private_key = file(var.pvt_key)
    }
  }
}

# /etc/hosts na każdym node — IDEMPOTENTNE (grep -qF zapobiega duplikatom przy re-apply).
resource "null_resource" "update_hosts" {
  for_each = {
    for i, addr in concat(digitalocean_droplet.cpnode.*.ipv4_address, digitalocean_droplet.knode.*.ipv4_address) : i => addr
  }

  depends_on = [digitalocean_droplet.cpnode, digitalocean_droplet.knode, digitalocean_loadbalancer.control_plane_lb]

  triggers = {
    cp1_priv = digitalocean_droplet.cpnode[0].ipv4_address_private
    cp2_priv = digitalocean_droplet.cpnode[1].ipv4_address_private
    cp3_priv = digitalocean_droplet.cpnode[2].ipv4_address_private
    kn1_priv = digitalocean_droplet.knode[0].ipv4_address_private
    kn2_priv = digitalocean_droplet.knode[1].ipv4_address_private
    kn3_priv = digitalocean_droplet.knode[2].ipv4_address_private
    lb_ip    = digitalocean_loadbalancer.control_plane_lb.ip
  }

  provisioner "remote-exec" {
    inline = [
      "grep -qF ' cpnode1.example.com' /etc/hosts || echo '${digitalocean_droplet.cpnode[0].ipv4_address_private} cpnode1.example.com cpnode1' >> /etc/hosts",
      "grep -qF ' cpnode2.example.com' /etc/hosts || echo '${digitalocean_droplet.cpnode[1].ipv4_address_private} cpnode2.example.com cpnode2' >> /etc/hosts",
      "grep -qF ' cpnode3.example.com' /etc/hosts || echo '${digitalocean_droplet.cpnode[2].ipv4_address_private} cpnode3.example.com cpnode3' >> /etc/hosts",
      "grep -qF ' knode1.example.com' /etc/hosts || echo '${digitalocean_droplet.knode[0].ipv4_address_private} knode1.example.com knode1' >> /etc/hosts",
      "grep -qF ' knode2.example.com' /etc/hosts || echo '${digitalocean_droplet.knode[1].ipv4_address_private} knode2.example.com knode2' >> /etc/hosts",
      "grep -qF ' knode3.example.com' /etc/hosts || echo '${digitalocean_droplet.knode[2].ipv4_address_private} knode3.example.com knode3' >> /etc/hosts",
      "grep -qF ' kubeapi.example.com' /etc/hosts || echo '${digitalocean_loadbalancer.control_plane_lb.ip} kubeapi.example.com kubeapi' >> /etc/hosts",
    ]

    connection {
      type        = "ssh"
      host        = each.value
      user        = "root"
      private_key = file(var.pvt_key)
    }
  }
}

output "cpnode_ips" {
  description = "Publiczne IP dropletów CP (do SSH)"
  value       = digitalocean_droplet.cpnode.*.ipv4_address
}

output "knode_ips" {
  description = "Publiczne IP dropletów worker (do SSH)"
  value       = digitalocean_droplet.knode.*.ipv4_address
}

output "control_plane_lb_ip" {
  description = "Publiczny IP DigitalOcean Load Balancera = kubeapi.example.com (controlPlaneEndpoint)"
  value       = digitalocean_loadbalancer.control_plane_lb.ip
}

output "cpnode_private_ips" {
  description = "Prywatne IP CP w VPC (advertiseAddress + certSANs zostały już wstawione)"
  value       = digitalocean_droplet.cpnode.*.ipv4_address_private
}
