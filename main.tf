provider "aws" {
  region = "us-east-2" 
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = true
}

resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-sg"
  description = "Allow traffic to Jenkins"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group_rule" "jenkins_sg_rule" {
  type        = "ingress"
  from_port   = 8080
  to_port     = 8080
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.jenkins_sg.id
}

resource "aws_ecs_cluster" "main" {
  name = "jenkins-cluster"
}

resource "aws_ecs_task_definition" "jenkins" {
  family                   = "jenkins-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name      = "jenkins"
      image     = "jenkins/jenkins:lts"
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "jenkins" {
  name            = "jenkins-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.jenkins.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  
  network_configuration {
    subnets          = [aws_subnet.main.id]
    security_groups = [aws_security_group.jenkins_sg.id]
    assign_public_ip = true
  }
}

output "jenkins_url" {
  value = "http://${aws_ecs_service.jenkins.id}.aws.com:8080"
}
