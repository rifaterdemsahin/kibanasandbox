terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = ">= 2.0.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

resource "digitalocean_vpc" "kibana_vpc" {
  name   = "kibana-vpc"
  region = var.region
}

resource "random_string" "security_encryption_key" {
  length  = 32
  special = false
}

resource "random_string" "reporting_encryption_key" {
  length  = 32
  special = false
}

resource "random_string" "saved_objects_encryption_key" {
  length  = 32
  special = false
}

resource "digitalocean_droplet" "kibana" {
  count = var.node_count
  image = "ubuntu-22-04-x64"
  name  = "kibana-${count.index}"
  region = var.region
  size   = var.droplet_size
  ssh_keys = [var.ssh_key_id]

  vpc_uuid = digitalocean_vpc.kibana_vpc.id

  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y apt-transport-https
    wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
    sh -c 'echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" > /etc/apt/sources.list.d/elastic-7.x.list'
    apt-get update
    apt-get install -y kibana

    # Set Kibana encryption keys and Elasticsearch connection
    cat <<EOL >> /etc/kibana/kibana.yml
    xpack.security.encryptionKey: "$(openssl rand -base64 32)"
    xpack.reporting.encryptionKey: "$(openssl rand -base64 32)"
    xpack.encryptedSavedObjects.encryptionKey: "$(openssl rand -base64 32)"
    elasticsearch.hosts: ["http://<elasticsearch_host>:9200"]
    EOL

    systemctl enable kibana
    systemctl start kibana
    EOF
}

resource "digitalocean_loadbalancer" "kibana_lb" {
  name   = "kibana-lb"
  region = var.region
  droplet_ids = digitalocean_droplet.kibana.*.id

  forwarding_rule {
    entry_port     = 80
    entry_protocol = "http"
    target_port    = 5601
    target_protocol = "http"
  }

  healthcheck {
    port     = 5601
    protocol = "http"
    path     = "/"
    check_interval_seconds = 10
    response_timeout_seconds = 5
    healthy_threshold = 5
    unhealthy_threshold = 3
  }

  vpc_uuid = digitalocean_vpc.kibana_vpc.id
}

output "kibana_url" {
  value = digitalocean_loadbalancer.kibana_lb.ip
}
