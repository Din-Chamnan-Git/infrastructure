# AWS Kubernetes Infrastructure with Terraform (Hands-On Guide & Notes)

This guide is designed for **hands-on learning and manual practice**. Follow the tasks below step-by-step to build a production-grade, multi-environment (`dev`, `staging`, `prod`) AWS Terraform setup for Kubernetes Master and Worker nodes.

---

## 📁 Target Directory Structure

When fully created, your `infra-k8s/terraform/` directory will look like this:

```
infra-k8s/terraform/
├── README.md                          # (This Guide & Practice Notes)
├── environments/                      # Environment-specific configurations
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── outputs.tf
│   ├── staging/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── outputs.tf
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       ├── terraform.tfvars
│       └── outputs.tf
│
└── modules/                           # Reusable AWS Infrastructure Modules
    ├── vpc/                           # Module 1: Network (VPC, Subnets, IGW)
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── security/                      # Module 2: Security Groups & K8s Firewall
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── k8s_nodes/                     # Module 3: EC2 Instances (Master & Worker pools)
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── kubespray_inventory/           # Module 4: Kubespray / Ansible Inventory Generator
        ├── main.tf
        ├── variables.tf
        └── templates/
            └── inventory.ini.tftpl
```

---

## 🎯 Task Roadmap & Learning Steps

- [ ] **Task 1**: Create Shared AWS Modules (`modules/`)
  - [ ] Task 1.1: Build `modules/vpc` (Network foundation)
  - [ ] Task 1.2: Build `modules/security` (K8s Security Groups)
  - [ ] Task 1.3: Build `modules/k8s_nodes` (EC2 Nodes with `for_each`)
  - [ ] Task 1.4: Build `modules/kubespray_inventory` (Inventory template)
- [ ] **Task 2**: Create Environment Configurations (`environments/`)
  - [ ] Task 2.1: Build `environments/dev` (Single master + worker)
  - [ ] Task 2.2: Build `environments/staging` (Staging cluster)
  - [ ] Task 2.3: Build `environments/prod` (HA 3-Master cluster)
- [ ] **Task 3**: Practice Terraform CLI Workflow (`init`, `plan`, `apply`)

---

## 🛠️ Detailed Task Instructions & Code Snippets

---

### Task 1: Building Reusable Shared Modules

#### Task 1.1: Network Module (`modules/vpc`)
Create directory: `modules/vpc/`

**Key Purpose**: Creates a dedicated AWS VPC, Public Subnet, Internet Gateway, and Route Table for your cluster.

1. **`modules/vpc/variables.tf`**:
```hcl
variable "cluster_name" {
  type        = string
  description = "Name of the Kubernetes cluster (e.g. k8s-dev)"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC (e.g. 10.10.0.0/16)"
  default     = "10.10.0.0/16"
}

variable "subnet_cidr" {
  type        = string
  description = "CIDR block for the public subnet (e.g. 10.10.1.0/24)"
  default     = "10.10.1.0/24"
}
```

2. **`modules/vpc/main.tf`**:
```hcl
resource "aws_vpc" "k8s_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.cluster_name}-vpc"
  }
}

resource "aws_internet_gateway" "k8s_igw" {
  vpc_id = aws_vpc.k8s_vpc.id

  tags = {
    Name = "${var.cluster_name}-igw"
  }
}

resource "aws_subnet" "k8s_public_subnet" {
  vpc_id                  = aws_vpc.k8s_vpc.id
  cidr_block              = var.subnet_cidr
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.cluster_name}-public-subnet"
  }
}

resource "aws_route_table" "k8s_public_rt" {
  vpc_id = aws_vpc.k8s_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.k8s_igw.id
  }

  tags = {
    Name = "${var.cluster_name}-public-rt"
  }
}

resource "aws_route_table_association" "k8s_public_assoc" {
  subnet_id      = aws_subnet.k8s_public_subnet.id
  route_table_id = aws_route_table.k8s_public_rt.id
}
```

3. **`modules/vpc/outputs.tf`**:
```hcl
output "vpc_id" {
  value = aws_vpc.k8s_vpc.id
}

output "subnet_id" {
  value = aws_subnet.k8s_public_subnet.id
}
```

---

#### Task 1.2: Security Group Module (`modules/security`)
Create directory: `modules/security/`

**Key Purpose**: Opens required firewall ports for Kubernetes master nodes, worker nodes, and CNI overlay networking.

1. **`modules/security/variables.tf`**:
```hcl
variable "cluster_name" { type = string }
variable "vpc_id"       { type = string }
```

2. **`modules/security/main.tf`**:
```hcl
# Master Nodes Security Group
resource "aws_security_group" "master_sg" {
  name        = "${var.cluster_name}-master-sg"
  description = "Security Group for K8s Master Control Plane"
  vpc_id      = var.vpc_id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kubernetes API Server
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # etcd server client API
  ingress {
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kubelet API
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Worker Nodes Security Group
resource "aws_security_group" "worker_sg" {
  name        = "${var.cluster_name}-worker-sg"
  description = "Security Group for K8s Worker Nodes"
  vpc_id      = var.vpc_id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kubelet API
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # NodePort Services Range
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow internal communication between cluster nodes (CNI overlay networking)
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

3. **`modules/security/outputs.tf`**:
```hcl
output "master_sg_id" { value = aws_security_group.master_sg.id }
output "worker_sg_id" { value = aws_security_group.worker_sg.id }
```

---

#### Task 1.3: Node Pool Module (`modules/k8s_nodes`)
Create directory: `modules/k8s_nodes/`

**Key Concept**: Uses `for_each` to create multiple EC2 instances based on a node definition map without duplicating code blocks!

1. **`modules/k8s_nodes/variables.tf`**:
```hcl
variable "cluster_name"    { type = string }
variable "subnet_id"       { type = string }
variable "security_group_id"{ type = string }
variable "key_name"        { type = string }
variable "ami_id"          { type = string }
variable "role"            { type = string } # "master" or "worker"

variable "nodes" {
  type = map(object({
    instance_type = string
    disk_size_gb  = number
  }))
}
```

2. **`modules/k8s_nodes/main.tf`**:
```hcl
resource "aws_instance" "node" {
  for_each = var.nodes

  ami                    = var.ami_id
  instance_type          = each.value.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name               = var.key_name

  root_block_device {
    volume_size           = each.value.disk_size_gb
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name        = each.key
    Role        = var.role
    ClusterName = var.cluster_name
  }
}
```

3. **`modules/k8s_nodes/outputs.tf`**:
```hcl
output "nodes" {
  value = {
    for k, v in aws_instance.node : k => {
      id         = v.id
      public_ip  = v.public_ip
      private_ip = v.private_ip
    }
  }
}
```

---

#### Task 1.4: Kubespray Inventory Generator Module (`modules/kubespray_inventory`)
Create directory: `modules/kubespray_inventory/`

1. **`modules/kubespray_inventory/templates/inventory.ini.tftpl`**:
```ini
[kube_control_plane]
%{ for name, node in master_nodes ~}
${name} ansible_host=${node.public_ip} ip=${node.private_ip}
%{ endfor ~}

[etcd]
%{ for name, node in master_nodes ~}
${name} ansible_host=${node.public_ip} ip=${node.private_ip}
%{ endfor ~}

[kube_node]
%{ for name, node in worker_nodes ~}
${name} ansible_host=${node.public_ip} ip=${node.private_ip}
%{ endfor ~}

[k8s_cluster:children]
kube_control_plane
kube_node
```

2. **`modules/kubespray_inventory/main.tf`**:
```hcl
resource "local_file" "kubespray_inventory" {
  content = templatefile("${path.module}/templates/inventory.ini.tftpl", {
    master_nodes = var.master_nodes
    worker_nodes = var.worker_nodes
  })
  filename = "${path.cwd}/inventory.ini"
}
```

---

### Task 2: Creating Environment Configurations

#### Task 2.1: Dev Environment (`environments/dev/`)

1. **`environments/dev/variables.tf`**:
```hcl
variable "aws_region"   { default = "us-east-1" }
variable "cluster_name" { default = "k8s-dev" }
variable "key_name"     { type = string }

variable "master_nodes" { type = map(any) }
variable "worker_nodes" { type = map(any) }
```

2. **`environments/dev/terraform.tfvars`**:
```hcl
aws_region   = "us-east-1"
cluster_name = "k8s-dev"
key_name     = "my-aws-ssh-key" # replace with your actual AWS key pair name

master_nodes = {
  "dev-master-1" = {
    instance_type = "t3.medium"
    disk_size_gb  = 30
  }
}

worker_nodes = {
  "dev-worker-1" = {
    instance_type = "t3.medium"
    disk_size_gb  = 40
  }
}
```

3. **`environments/dev/main.tf`**:
```hcl
provider "aws" {
  region = var.aws_region
}

# 1. VPC Module
module "vpc" {
  source       = "../../modules/vpc"
  cluster_name = var.cluster_name
  vpc_cidr     = "10.10.0.0/16"
  subnet_cidr  = "10.10.1.0/24"
}

# 2. Security Module
module "security" {
  source       = "../../modules/security"
  cluster_name = var.cluster_name
  vpc_id       = module.vpc.vpc_id
}

# Ubuntu 22.04 LTS AMI Data Source
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# 3. Master Nodes Pool
module "masters" {
  source             = "../../modules/k8s_nodes"
  cluster_name       = var.cluster_name
  subnet_id          = module.vpc.subnet_id
  security_group_id  = module.security.master_sg_id
  key_name           = var.key_name
  ami_id             = data.aws_ami.ubuntu.id
  role               = "master"
  nodes              = var.master_nodes
}

# 4. Worker Nodes Pool
module "workers" {
  source             = "../../modules/k8s_nodes"
  cluster_name       = var.cluster_name
  subnet_id          = module.vpc.subnet_id
  security_group_id  = module.security.worker_sg_id
  key_name           = var.key_name
  ami_id             = data.aws_ami.ubuntu.id
  role               = "worker"
  nodes              = var.worker_nodes
}

# 5. Inventory Generator
module "inventory" {
  source       = "../../modules/kubespray_inventory"
  master_nodes = module.masters.nodes
  worker_nodes = module.workers.nodes
}
```

4. **`environments/dev/outputs.tf`**:
```hcl
output "master_public_ips" {
  value = { for k, v in module.masters.nodes : k => v.public_ip }
}

output "worker_public_ips" {
  value = { for k, v in module.workers.nodes : k => v.public_ip }
}
```

---

#### Task 2.2 & 2.3: Staging and Prod Configurations
To create `staging` and `prod`, copy the `dev/` directory structure to `staging/` and `prod/`, adjusting `terraform.tfvars`:

- **Staging (`environments/staging/terraform.tfvars`)**:
  - `vpc_cidr = "10.20.0.0/16"`
  - 1 Master + 2 Workers (`t3.large`)

- **Prod (`environments/prod/terraform.tfvars`)**:
  - `vpc_cidr = "10.30.0.0/16"`
  - 3 Masters (for etcd High Availability) + 3+ Workers (`t3.large` or `t3.xlarge`).

---

## 🚀 Execution & Verification Workflow

Whenever you are ready to test one of your environments manually:

```bash
# Step 1: Navigate to the desired environment directory
cd infra-k8s/terraform/environments/dev

# Step 2: Initialize Terraform and download providers/modules
terraform init

# Step 3: Preview execution plan
terraform plan

# Step 4: Provision nodes on AWS
terraform apply -auto-approve

# Step 5: Check the auto-generated inventory file
cat inventory.ini
```

---

## 📝 Practice Notes & Key Takeaways

1. **`for_each` vs `count`**:
   Using `for_each` with maps (`master_nodes`, `worker_nodes`) allows you to add or remove individual nodes by name without Terraform recreating all other nodes.
2. **Modular VPC & Security**:
   Centralizing VPC and Security Group logic inside `modules/` makes your environment files (`main.tf`) very short, clean, and readable.
3. **Environment Isolation**:
   Running `terraform apply` in `environments/dev` only affects the dev cluster state file (`environments/dev/terraform.tfstate`), keeping `staging` and `prod` safe.
