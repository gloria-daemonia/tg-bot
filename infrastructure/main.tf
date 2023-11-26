# make tf tests in future

#VPC
#security group ergess all

resource "aws_ecs_cluster" "this" {
  name = "Tg-bot-fargate-cluster-${var.env_name}"
  # configuration {
  #   execute_command_configuration {
  #     log_configuration {

  #     }
  #   }
  # }
  tags = merge(
    { "Name" = "Tg bot Fargate cluster" },
    var.tags
  )
}

#IAM role
#Secret with api-key

resource "aws_ecs_task_definition" "this" {
  family                   = "Tg-bot-${var.env_name}"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 64
  memory                   = 64
  network_mode             = "awsvpc"
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
  execution_role_arn = "arn_for_docker_daemon_to_assume_to_get_the_secret"
  task_role_arn      = "arn_for_task"

  container_definitions = <<CONTAINER_DEFINITION
  [
    {
      "name": "tg-bot",
      "image": "pandemonic/fastiv-youth-bot:latest",
      "memoryReservation": 10,
      "memory": 64,
      "cpu": 64
      "essential": false,
      "environment": [{"name": "ENV_TAG", "value": "${var.env_name}"}],
      "secrets": [{
        "name": "TELEGRAM_APITOKEN",
        "valueFrom": "full arn secrets manager"
      }]
    }
  ]
  CONTAINER_DEFINITION

  tags = merge(
    { "Name" = "Tg bot Task Definition" },
    var.tags
  )
}

resource "aws_ecs_service" "this" {
  name    = "Tg-bot-${var.env_name}"
  cluster = aws_ecs_cluster.this.arn

  task_definition  = aws_ecs_task_definition.this.arn
  desired_count    = 1
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  network_configuration {
    subnets          = ["value"]
    security_groups  = ["value"]
    assign_public_ip = false
  }

  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0

  # force_new_deployment = true
  triggers = {
    redeployment = timestamp()
    # 
  }

  tags = merge(
    { "Name" = "Tg bot ECS Service" },
    var.tags
  )
}

# monitoring to cloudwatch
