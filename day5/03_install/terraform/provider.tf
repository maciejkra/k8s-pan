terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

variable "do_token" {
  description = "DigitalOcean API token (https://cloud.digitalocean.com/account/api/tokens)"
  type        = string
  sensitive   = true
}

variable "ssh_key_name" {
  description = "Nazwa klucza SSH zarejestrowanego w DO (Settings → Security → SSH Keys)"
  type        = string
}

variable "pvt_key" {
  description = "Ścieżka do prywatnego klucza SSH na lokalnej maszynie (do remote-exec)"
  type        = string
  default     = "~/.ssh/id_rsa"
}

provider "digitalocean" {
  token = var.do_token
}

data "digitalocean_ssh_key" "terraform" {
  name = var.ssh_key_name
}
