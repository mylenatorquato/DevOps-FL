provider "aws" {
  region = "us-east-2"
}

# Variables
variable "DevOpsfl" {
  description = "AppDevOps"
  default     = "DevOpsfl"
}

variable "environment" {
  description = "Deployment environment"
  default     = "dev"
}

# VPC
resource "aws_vpc" "app_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.DevOpsfl}-vpc"
    Environment = var.environment
  }
}

# Internet Gateway
resource "aws_internet_gateway" "app_igw" {
  vpc_id = aws_vpc.app_vpc.id

  tags = {
    Name        = "${var.DevOpsfl}-igw"
    Environment = var.environment
  }
}

# Public Subnet
resource "aws_subnet" "app_public_subnet" {
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.DevOpsfl}-public-subnet"
    Environment = var.environment
  }
}

# Route Table
resource "aws_route_table" "app_public_rt" {
  vpc_id = aws_vpc.app_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.app_igw.id
  }

  tags = {
    Name        = "${var.DevOpsfl}-public-route-table"
    Environment = var.environment
  }
}

# Route Table Association
resource "aws_route_table_association" "app_public_rta" {
  subnet_id      = aws_subnet.app_public_subnet.id
  route_table_id = aws_route_table.app_public_rt.id
}

# Security Group for EC2
resource "aws_security_group" "app_sg" {
  name        = "${var.DevOpsfl}-security-group"
  description = "Security group for EC2"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.DevOpsfl}-security-group"
    Environment = var.environment
  }
}

# Key Pair
resource "aws_key_pair" "app_key" {
  key_name   = "opsnake"
  public_key = file("~/.ssh/opsnake.pub")

  tags = {
    Name        = "chave"
    Environment = var.environment
  }
}

# EC2 Instance
resource "aws_instance" "app_server" {
  ami                    = "ami-0c55b159cbfafe1f0"  # Amazon Linux 2 AMI
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.app_key.key_name
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  subnet_id              = aws_subnet.app_public_subnet.id

 user_data = <<-EOF
              #!/bin/bash
              yum update -y
              sudo amazon-linux-extras enable corretto17
              sudo yum install java-17-amazon-corretto -y

              # Add Jenkins repository
              sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
              sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
              sudo yum install jenkins -y
              sudo systemctl enable jenkins
              sudo systemctl start jenkins

              # Open the Jenkins port
              sudo firewall-cmd --zone=public --add-port=8080/tcp --permanent
              sudo firewall-cmd --reload
              EOF

  tags = {
    Name        = "${var.DevOpsfl}-server"
    Environment = var.environment
  }
}
