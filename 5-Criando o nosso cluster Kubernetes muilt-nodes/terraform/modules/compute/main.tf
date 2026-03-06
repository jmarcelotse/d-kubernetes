# Key Pair
resource "aws_key_pair" "main" {
  key_name   = "${var.cluster_name}-key"
  public_key = file(var.public_key_path)
}

# AMI Ubuntu 22.04
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Master Nodes
resource "aws_instance" "masters" {
  count                  = var.master_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.master_instance_type
  key_name               = aws_key_pair.main.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  private_ip             = "10.0.1.${10 + count.index}"

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = file("${path.module}/user-data.sh")

  tags = {
    Name    = "${var.cluster_name}-master-${count.index + 1}"
    Cluster = var.cluster_name
    Role    = "master"
  }
}

# Worker Nodes
resource "aws_instance" "workers" {
  count                  = var.worker_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.worker_instance_type
  key_name               = aws_key_pair.main.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  private_ip             = "10.0.1.${20 + count.index}"

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

  user_data = file("${path.module}/user-data.sh")

  tags = {
    Name    = "${var.cluster_name}-worker-${count.index + 1}"
    Cluster = var.cluster_name
    Role    = "worker"
  }
}
