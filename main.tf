provider "digitalocean" {
  token = var.do_token
}

resource "digitalocean_vpc" "kibana_vpc" {
  name   = "kibana-vpc"
  region = var.region
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
    systemctl enable kibana
    systemctl start kibana
    EOF
}

resource "digitalocean_loadbalancer" "kibana_lb" {
  name   = "kibana-lb"
  region = var.region
  forwarding_rule {
    entry_protocol  = "http"
    entry_port      = 80
    target_protocol = "http"
    target_port     = 5601
  }

  healthcheck {
    protocol               = "http"
    port                   = 5601
    check_interval_seconds = 10
    response_timeout_seconds = 5
    healthy_threshold      = 5
    unhealthy_threshold    = 3
  }

  droplet_ids = digitalocean_droplet.kibana.*.id
}

output "kibana_url" {
  value = digitalocean_loadbalancer.kibana_lb.ip
}
