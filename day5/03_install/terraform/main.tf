resource "digitalocean_loadbalancer" "control_plane_lb" {
  name        = "control-plane-lb"
  region      = "fra1"
  
  forwarding_rule {
    entry_protocol   = "tcp"
    entry_port       = 443
    target_protocol  = "tcp"
    target_port      = 443
  }

  forwarding_rule {
    entry_protocol   = "tcp"
    entry_port       = 6443
    target_protocol  = "tcp"
    target_port      = 6443
  }

  forwarding_rule {
    entry_protocol   = "tcp"
    entry_port       = 80
    target_protocol  = "tcp"
    target_port      = 80
  }

  healthcheck {
    protocol              = "tcp"
    port                  = 6443
    check_interval_seconds = 5
    response_timeout_seconds = 3
    healthy_threshold     = 3
    unhealthy_threshold   = 3
  }

  droplet_tag = "control-plane"
}

resource "digitalocean_droplet" "cpnode" {
  count              = 3
  name               = "cpnode${count.index + 1}"
  image              = "ubuntu-24-04-x64"
  region             = "fra1"
  size               = "s-2vcpu-4gb"
  tags               = ["control-plane"]
  ssh_keys = [
      data.digitalocean_ssh_key.terraform.id
  ]

  provisioner "remote-exec" {
    inline = [
      "until echo 'Checking if SSH is ready' && exit; do echo 'Waiting for SSH...'; sleep 10; done"
    ]

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

  provisioner "file" {
    source      = "../kubeadm-config.yaml"
    destination = "/root/kubeadm-config.yaml"

    connection {
      type        = "ssh"
      host        = self.ipv4_address
      user        = "root"
      private_key = file(var.pvt_key)
    }
  }

  provisioner "file" {
    source      = "../kube-vip-static-pod.yaml"
    destination = "/root/kube-vip-static-pod.yaml"

    connection {
      type        = "ssh"
      host        = self.ipv4_address
      user        = "root"
      private_key = file(var.pvt_key)
    }
  }

  # audit-policy.yaml + enc.yaml → /etc/kubernetes/ na CP node
  # (`/etc/kubernetes` przed kubeadm init nie istnieje — robimy mkdir w remote-exec)
  provisioner "remote-exec" {
    inline = ["mkdir -p /etc/kubernetes"]
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

  provisioner "file" {
    source      = "../kubernetes/enc.yaml"
    destination = "/etc/kubernetes/enc.yaml"
    connection {
      type        = "ssh"
      host        = self.ipv4_address
      user        = "root"
      private_key = file(var.pvt_key)
    }
  }

  provisioner "remote-exec" {
    # Inline script with retry logic
  inline = [
    "sleep 15; sudo bash /root/prepare.sh"
  ]
    
    connection {
      type        = "ssh"
      host        = self.ipv4_address
      user        = "root"
      private_key = file(var.pvt_key)
    }
  }

}

resource "digitalocean_droplet" "knode" {
  count              = 3
  name               = "knode${count.index + 1}"
  image              = "ubuntu-24-04-x64"
  region             = "fra1"
  size               = "s-2vcpu-4gb"
  tags               = ["worker"]
  ssh_keys = [
      data.digitalocean_ssh_key.terraform.id
  ]


  provisioner "remote-exec" {
    inline = [
      "until echo 'Checking if SSH is ready' && exit; do echo 'Waiting for SSH...'; sleep 10; done"
    ]

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
    # Inline script with retry logic
  inline = [
    "sleep 15; sudo bash /root/prepare.sh"
  ]
    
    connection {
      type        = "ssh"
      host        = self.ipv4_address
      user        = "root"
      private_key = file(var.pvt_key)
    }
  }
}

resource "null_resource" "hosts_file" {
  # Runs after droplets + LB are created. Generuje ../hosts dla referencji
  # (ten plik jest też wczytywany do /etc/hosts na każdym node przez null_resource.update_hosts).
  depends_on = [digitalocean_droplet.cpnode, digitalocean_droplet.knode, digitalocean_loadbalancer.control_plane_lb]

  provisioner "local-exec" {
    command = <<-EOT
      cat > ../hosts <<HOSTS
      ${digitalocean_droplet.cpnode[0].ipv4_address_private} cpnode1.example.com cpnode1
      ${digitalocean_droplet.cpnode[1].ipv4_address_private} cpnode2.example.com cpnode2
      ${digitalocean_droplet.cpnode[2].ipv4_address_private} cpnode3.example.com cpnode3
      ${digitalocean_droplet.knode[0].ipv4_address_private} knode1.example.com knode1
      ${digitalocean_droplet.knode[1].ipv4_address_private} knode2.example.com knode2
      ${digitalocean_droplet.knode[2].ipv4_address_private} knode3.example.com knode3
      ${digitalocean_loadbalancer.control_plane_lb.ip} kubeapi.example.com kubeapi
      HOSTS
    EOT
  }
}

resource "null_resource" "update_hosts" {
  for_each = {
    for i, addr in concat(digitalocean_droplet.cpnode.*.ipv4_address, digitalocean_droplet.knode.*.ipv4_address) : i => addr
  }

  provisioner "remote-exec" {
    inline = [
      "echo '${digitalocean_droplet.cpnode[0].ipv4_address_private} cpnode1.example.com cpnode1' >> /etc/hosts",
      "echo '${digitalocean_droplet.cpnode[1].ipv4_address_private} cpnode2.example.com cpnode2' >> /etc/hosts",
      "echo '${digitalocean_droplet.cpnode[2].ipv4_address_private} cpnode3.example.com cpnode3' >> /etc/hosts",
      "echo '${digitalocean_droplet.knode[0].ipv4_address_private} knode1.example.com knode1' >> /etc/hosts",
      "echo '${digitalocean_droplet.knode[1].ipv4_address_private} knode2.example.com knode2' >> /etc/hosts",
      "echo '${digitalocean_droplet.knode[2].ipv4_address_private} knode3.example.com knode3' >> /etc/hosts",
      "echo '${digitalocean_loadbalancer.control_plane_lb.ip} kubeapi.example.com kubeapi' >> /etc/hosts"
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
  description = "Prywatne IP CP (VPC) — dodaj do certSANs w kubeadm-config.yaml"
  value       = digitalocean_droplet.cpnode.*.ipv4_address_private
}
