provider "aws" {
  region = "us-west-2"
}

resource "aws_ecs_cluster" "fargate_cluster" {
  name = "my-fargate-cluster"
}

resource "aws_ecs_task_definition" "java_task" {
  family                   = "java-app"
  execution_role_arn       = aws_iam_role.task_execution.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  container_definitions = jsonencode([
    {
      name  = "java-app"
      image = "my-registry/my-java-app:latest"
      port_mappings = [
        {
          container_port = 8080
          protocol       = "tcp"
        },
      ],
      environment = [
        {
          name  = "DYNAMODB_REGION"
          value = "us-west-2"
        },
        {
          name  = "DYNAMODB_TABLE"
          value = "my-table"
        },
      ],
      log_configuration = {
        log_driver = "awslogs"
        options    = {
          "awslogs-group"         = "my-logs"
          "awslogs-region"        = "us-west-2"
          "awslogs-stream-prefix" = "java-app"
        }
      }
    },
  ])
}

resource "aws_ecs_service" "java_service" {
  name        = "java-service"
  cluster     = aws_ecs_cluster.fargate_cluster.id
  task_definition = aws_ecs_task_definition.java_task.arn
  desired_count = 1

  network_configuration {
    awsvpc_configuration {
      subnets          = aws_subnet.private.*.id
      security_groups  = [aws_security_group.ecs_security_group.id]
      assign_public_ip = false
    }
  }
}

resource "aws_iam_role" "task_execution" {
  name = "ecsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "task_execution_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.task_execution.name
}

resource "aws_security_group" "ecs_security_group" {
  name_prefix = "ecs-sg"

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_subnet" "private" {
  count = 2
  cidr_block = "10.0.${count.index+1}.0/24"
}

