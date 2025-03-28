# Comment out or remove the VPC creation
# resource "aws_vpc" "main" { ... }

# Use data source to reference existing VPC
data "aws_vpc" "existing" {
  default = true  # This will use the default VPC
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = data.aws_vpc.existing.id
  cidr_block             = "172.31.96.0/20"  # Make sure this doesn't overlap with existing subnets
  availability_zone      = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.app_name}-public-subnet"
    Environment = var.environment
  }
}

# Security Group
resource "aws_security_group" "app_sg" {
  name        = "${var.app_name}-sg"
  description = "Security group for Streamlit app"
  vpc_id      = data.aws_vpc.existing.id

  ingress {
    from_port   = 8501
    to_port     = 8501
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Streamlit application port"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.app_name}-sg"
    Environment = var.environment
  }
}

# EC2 Instance
resource "aws_instance" "app_server" {
  ami           = "ami-0230bd60aa48260c6"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id

  vpc_security_group_ids = [aws_security_group.app_sg.id]

  tags = {
    Name        = "${var.app_name}-server"
    Environment = var.environment
  }
}

# ECR Repository
resource "aws_ecr_repository" "app" {
  name = "streamlit-app"
  image_scanning_configuration {
    scan_on_push = true
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "streamlit-cluster"
}

# Add ECS IAM Role
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.app_name}-ecs-task-execution-role"

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

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Update the ECS task definition to use the VPC and IAM role
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.app_name}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode            = "awsvpc"
  cpu                     = 256
  memory                  = 512
  execution_role_arn      = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name  = var.app_name
      image = "${aws_ecr_repository.app.repository_url}:latest"
      portMappings = [
        {
          containerPort = 8501
          hostPort      = 8501
          protocol      = "tcp"
        }
      ]
    }
  ])
}

# Update ECS Service
resource "aws_ecs_service" "app" {
  name            = "${var.app_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 0  # Change to 0 when not using
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public.id]
    security_groups  = [aws_security_group.app_sg.id]
    assign_public_ip = true
  }
}

# Use existing Internet Gateway
data "aws_internet_gateway" "default" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.existing.id]
  }
}

# Update Route Table to use existing IGW
resource "aws_route_table" "public" {
  vpc_id = data.aws_vpc.existing.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.aws_internet_gateway.default.id
  }

  tags = {
    Name        = "${var.app_name}-public-rt"
    Environment = var.environment
  }
}

# Associate Route Table with Subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Add CodeBuild IAM Role
resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Add CodeBuild Project
resource "aws_codebuild_project" "app_build" {
  name         = "streamlit-app-build"
  description  = "Builds Streamlit app Docker image"
  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                      = "aws/codebuild/standard:5.0"
    type                       = "LINUX_CONTAINER"
    privileged_mode            = true

    environment_variable {
      name  = "ECR_REPOSITORY_URI"
      value = aws_ecr_repository.app.repository_url
    }
  }

  source {
    type = "GITHUB"
    location = "https://github.com/Guruprasadaj/aws-streamlit-demo.git"
    buildspec = "buildspec.yml"
  }
}

# Add Application Auto Scaling
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 1
  min_capacity       = 0
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Scale based on schedule (up during work hours, down otherwise)
resource "aws_appautoscaling_scheduled_action" "scale_up" {
  name               = "scale-up"
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  schedule           = "cron(0 9 ? * MON-FRI *)"  # 9 AM UTC weekdays

  scalable_target_action {
    min_capacity = 1
    max_capacity = 1
  }
}

resource "aws_appautoscaling_scheduled_action" "scale_down" {
  name               = "scale-down"
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  schedule           = "cron(0 17 ? * MON-FRI *)"  # 5 PM UTC weekdays

  scalable_target_action {
    min_capacity = 0
    max_capacity = 0
  }
}

# Add CodeBuild IAM policy
resource "aws_iam_role_policy" "codebuild_policy" {
  role = aws_iam_role.codebuild_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Resource = ["*"]
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
      },
      {
        Effect = "Allow"
        Resource = ["*"]
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
      }
    ]
  })
}
