# 1. VPC Module
module "vpc" {
  source                     = "../../modules/aws/vpc"
  vpc_cidr                   = var.vpc_cidr
  subnet_cidr                 = var.subnet_cidr
  availability_zone           = var.availability_zone
  subnet_2_cidr              = var.subnet_2_cidr
  subnet_2_availability_zone = var.subnet_2_availability_zone
  environment                = var.environment
}

# 2. Security Group Module
module "security_group" {
  source      = "../../modules/aws/security_group"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
}

# SSH Key Pair shared across all nodes
resource "aws_key_pair" "k8s_key" {
  key_name   = "k8s-key-${var.environment}"
  public_key = file(var.public_key_path)

  tags = {
    Name = "k8s-key-${var.environment}"
  }
}

# 3. K8s Master Nodes (EC2 Module)
module "master_nodes" {
  source            = "../../modules/aws/ec2"
  subnet_id         = module.vpc.subnet_id
  security_group_id = module.security_group.master_sg_id
  environment       = var.environment
  nodes             = var.master_nodes
  key_name          = aws_key_pair.k8s_key.key_name
}

# # 4. K8s Worker Nodes (EC2 Module)
# module "worker_nodes" {
#   source            = "../../modules/aws/ec2"
#   subnet_id         = module.vpc.subnet_id
#   security_group_id = module.security_group.worker_sg_id
#   environment       = var.environment
#   nodes             = var.worker_nodes
#   key_name          = aws_key_pair.k8s_key.key_name
# }

# # 5. Application Load Balancer
# module "alb" {
#   source            = "../../modules/aws/alb"
#   environment       = var.environment
#   vpc_id            = module.vpc.vpc_id
#   public_subnet_ids = module.vpc.subnet_ids
#   domain_name       = var.domain_name
#   subdomain         = var.subdomain
# }
