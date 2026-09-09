variable "region" {
  type        = string
  description = "The GCP region to deploy the load balancer in"
}

variable "network_name" {
  type        = string
  description = "The name of the VPC network"
}

variable "worker_self_links" {
  type        = list(string)
  description = "List of worker VM self_links to attach to the load balancer target pool"
}
