terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC and Networking
resource "aws_vpc" "n8n_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "n8n-vpc"
  }
}

resource "aws_subnet" "n8n_public_subnet" {
  vpc_id                  = aws_vpc.n8n_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "n8n-public-subnet"
  }
}

resource "aws_subnet" "n8n_private_subnet" {
  vpc_id            = aws_vpc.n8n_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "n8n-private-subnet"
  }
}

resource "aws_internet_gateway" "n8n_igw" {
  vpc_id = aws_vpc.n8n_vpc.id

  tags = {
    Name = "n8n-igw"
  }
}

resource "aws_route_table" "n8n_public_rt" {
  vpc_id = aws_vpc.n8n_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.n8n_igw.id
  }

  tags = {
    Name = "n8n-public-rt"
  }
}

resource "aws_route_table_association" "n8n_public_rta" {
  subnet_id      = aws_subnet.n8n_public_subnet.id
  route_table_id = aws_route_table.n8n_public_rt.id
}

# Security Groups
resource "aws_security_group" "n8n_ec2_sg" {
  name        = "n8n-ec2-sg"
  description = "Security group for n8n EC2 instance"
  vpc_id      = aws_vpc.n8n_vpc.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "n8n-ec2-sg"
  }
}

resource "aws_security_group" "n8n_rds_sg" {
  name        = "n8n-rds-sg"
  description = "Security group for n8n RDS instance"
  vpc_id      = aws_vpc.n8n_vpc.id

  ingress {
    description     = "PostgreSQL"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.n8n_ec2_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "n8n-rds-sg"
  }
}

# EC2 Instance
resource "aws_instance" "n8n_server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.n8n_ec2_sg.id]
  subnet_id              = aws_subnet.n8n_public_subnet.id
  user_data              = templatefile("${path.module}/user_data.sh", {
    domain = var.domain_name
    email  = var.admin_email
  })

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "n8n-server"
  }
}

# Elastic IP
resource "aws_eip" "n8n_eip" {
  instance = aws_instance.n8n_server.id
  domain   = "vpc"

  tags = {
    Name = "n8n-eip"
  }
}

# RDS Subnet Group
resource "aws_db_subnet_group" "n8n_db_subnet_group" {
  name       = "n8n-db-subnet-group"
  subnet_ids = [aws_subnet.n8n_private_subnet.id]

  tags = {
    Name = "n8n-db-subnet-group"
  }
}

# RDS Instance
resource "aws_db_instance" "n8n_database" {
  identifier = "n8n-db"

  engine         = "postgres"
  engine_version = "15.4"
  instance_class = var.db_instance_class

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "n8n"
  username = "n8n"
  password = var.db_password

  vpc_security_group_ids = [aws_security_group.n8n_rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.n8n_db_subnet_group.name

  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name = "n8n-database"
  }
}

# Route53 DNS Record (if domain is provided)
resource "aws_route53_record" "n8n_dns" {
  count = var.domain_name != "" ? 1 : 0

  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = "300"
  records = [aws_eip.n8n_eip.public_ip]
}

# Outputs
output "n8n_server_public_ip" {
  description = "Public IP of the n8n server"
  value       = aws_eip.n8n_eip.public_ip
}

output "n8n_server_private_ip" {
  description = "Private IP of the n8n server"
  value       = aws_instance.n8n_server.private_ip
}

output "n8n_database_endpoint" {
  description = "RDS database endpoint"
  value       = aws_db_instance.n8n_database.endpoint
}

output "n8n_url" {
  description = "URL to access n8n"
  value       = var.domain_name != "" ? "https://${var.domain_name}" : "http://${aws_eip.n8n_eip.public_ip}"
} 