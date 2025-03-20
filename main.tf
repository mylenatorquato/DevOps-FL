provider "aws" {
  region = "us-east-2"
}

# VPC Configuration
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  
  tags = {
    Name = "jenkins-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "jenkins-igw"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  
  tags = {
    Name = "jenkins-public-rt"
  }
}

# Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "jenkins-public-subnet"
  }
}

# Route Table Association
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-sg"
  description = "Allow traffic to Jenkins"
  vpc_id      = aws_vpc.main.id
  
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
    description = "Jenkins web interface"
  }
  
  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "EFS mount target"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
  
  tags = {
    Name = "jenkins-sg"
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "jenkins_cluster" {
  name = "jenkins-cluster"
  
  tags = {
    Name = "jenkins-cluster"
  }
}

# EFS for Jenkins data persistence
resource "aws_efs_file_system" "jenkins_data" {
  creation_token = "jenkins-data"
  
  tags = {
    Name = "jenkins-data"
  }
}

resource "aws_efs_mount_target" "jenkins_data_mount" {
  file_system_id  = aws_efs_file_system.jenkins_data.id
  subnet_id       = aws_subnet.public.id
  security_groups = [aws_security_group.jenkins_sg.id]
}

# ECR Repository
resource "aws_ecr_repository" "jenkins_repo" {
  name                 = "jenkins-repo"
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
}

# EC2 Instance - Free Tier eligible t2.micro
resource "aws_instance" "jenkins_host" {
  ami                    = "ami-0d0f28110d16ee7d6"  
  instance_type          = "t2.micro"  
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]
  key_name               = "jenkins"
  
  user_data = <<-EOF
              #!/bin/bash
              echo "ECS_CLUSTER=${aws_ecs_cluster.jenkins_cluster.name}" >> /etc/ecs/ecs.config
              yum install -y amazon-efs-utils
              mkdir -p /efs
              mount -t efs ${aws_efs_file_system.jenkins_data.id}:/ /efs
              echo "${aws_efs_file_system.jenkins_data.id}:/ /efs efs defaults,_netdev 0 0" >> /etc/fstab
              EOF
  
  tags = {
    Name = "jenkins-ec2-host"
  }
  
  depends_on = [
    aws_efs_mount_target.jenkins_data_mount
  ]
}

# ECS Task Definition
resource "aws_ecs_task_definition" "jenkins" {
  family                   = "jenkins"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  
  volume {
    name      = "jenkins-data"
    host_path = "/efs/jenkins-data"
  }
  
  container_definitions = jsonencode([
    {
      name      = "jenkins"
      image     = "${aws_ecr_repository.jenkins_repo.repository_url}:latest"
      essential = true
      
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        },
        {
          containerPort = 50000
          hostPort      = 50000
          protocol      = "tcp"
        }
      ]
      
      mountPoints = [
        {
          sourceVolume  = "jenkins-data"
          containerPath = "/var/jenkins_home"
          readOnly      = false
        }
      ]
      
      memory = 750
      cpu    = 500
    }
  ])
  
  tags = {
    Name = "jenkins-task-definition"
  }
}

# ECS Service
resource "aws_ecs_service" "jenkins" {
  name            = "jenkins-service"
  cluster         = aws_ecs_cluster.jenkins_cluster.id
  task_definition = aws_ecs_task_definition.jenkins.arn
  desired_count   = 1
  
  # No Application Load Balancer to save costs
  # Uses host networking mode directly exposing ports
  
  depends_on = [
    aws_instance.jenkins_host
  ]
}

# Outputs
output "jenkins_url" {
  value = "http://${aws_instance.jenkins_host.public_ip}:8080"
  description = "URL of the Jenkins server"
}

output "ecr_repository_url" {
  value = aws_ecr_repository.jenkins_repo.repository_url
  description = "URL of the ECR repository"
}
