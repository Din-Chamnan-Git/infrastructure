# 1. Call the GCP VPC network module
module "vpc" {
  source        = "../../modules/gcp/gcp_vpc"
  network_name  = "gcp-k8s-vpc"
  subnet_name   = "gcp-k8s-subnet"
  ip_cidr_range = "10.10.1.0/24"
  region        = var.region
}

# 2. Call the GCP Firewall rules module
module "firewall" {
  source        = "../../modules/gcp/gcp_firewall"
  network_name  = module.vpc.network_name
  ip_cidr_range = "10.10.1.0/24"
}

# 3. Call the GCP Compute Instances module
module "compute" {
  source          = "../../modules/gcp/gcp_compute"
  zone            = var.zone
  subnet_name     = module.vpc.subnet_name
  public_key_path = var.public_key_path
  nodes = {
    # 1 Master Node (Fits within the 4-IP Free Trial limit)
    "k8s-master-1" = {
      role         = "master"
      machine_type = "e2-medium"
      disk_size_gb = 30
    }

    # 2 Worker Nodes
    "k8s-worker-1" = {
      role         = "worker"
      machine_type = "e2-medium"
      disk_size_gb = 50
    }
    "k8s-worker-2" = {
      role         = "worker"
      machine_type = "e2-medium"
      disk_size_gb = 50
    }
  }
}

# 4. Call the GCP Load Balancer module
module "lb" {
  source            = "../../modules/gcp/gcp_lb"
  region            = var.region
  network_name      = module.vpc.network_name
  worker_self_links = module.compute.worker_self_links
}

# Output the Load Balancer Public IP
output "lb_public_ip" {
  value       = module.lb.lb_public_ip
  description = "The external public IP of your load balancer"
}


# Output the VM IP addresses so we can configure Kubespray later
output "node_ips" {
  value       = module.compute.node_ips
  description = "Public and Private IP addresses of all provisioning nodes"
}

# 5. Manage Cloudflare DNS records
resource "cloudflare_record" "app" {
  zone_id = var.cloudflare_zone_id
  name    = "app"
  content = module.lb.lb_public_ip
  type    = "A"
  proxied = true # Enabled Orange Cloud (Proxy) for HTTPS
}

resource "cloudflare_record" "argocd" {
  zone_id = var.cloudflare_zone_id
  name    = "argocd"
  content = module.lb.lb_public_ip
  type    = "A"
  proxied = true # Enabled Orange Cloud (Proxy) for HTTPS
}

resource "cloudflare_record" "longhorn" {
  zone_id = var.cloudflare_zone_id
  name    = "longhorn"
  content = module.lb.lb_public_ip
  type    = "A"
  proxied = true # Enabled Orange Cloud (Proxy) for HTTPS
}


