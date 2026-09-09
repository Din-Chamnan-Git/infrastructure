# create the global VPC network 
resource "google_compute_network" "vpc"{
    name = var.network_name
    auto_create_subnetworks = false 
}


# create the our spacific subnet inside the vpc
resource "google_compute_subnetwork" "subnet"{
    name          = var.subnet_name
    ip_cidr_range = var.ip_cidr_range
    region        = var.region
    network       = google_compute_network.vpc.id  
}

