variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
}

variable "region" {
  description = "The region to deploy the resources in"
  type        = string
  default     = "lon1"
}

variable "droplet_size" {
  description = "The size of the droplet"
  type        = string
  default     = "s-1vcpu-2gb"
}

variable "node_count" {
  description = "The number of Kibana nodes"
  type        = number
  default     = 2
}

variable "ssh_key_id" {
  description = "The SSH key ID to access the droplets"
  type        = string
}
