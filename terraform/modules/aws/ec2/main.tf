# Ubuntu 22.04 LTS AMI Data Source
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 Instances (Creates multiple nodes dynamically using for_each)
resource "aws_instance" "node" {
  for_each = var.nodes

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = each.value.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [var.security_group_id]
  subnet_id              = var.subnet_id

  root_block_device {
    volume_size           = each.value.disk_size_gb
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name        = "${each.key}-${var.environment}"
    Role        = each.value.role
    Environment = var.environment
  }
}
