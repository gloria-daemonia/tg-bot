# pricing:
# fargate (spot, 0.25 vCPU, 0.5 GB) = 0.01344461*0.25 + 0.00148042*0.5 = $0.0041013625/h = $2.952981/month
# secret = $0.4/month
# public ip v4 (from 01.02.2024)= $0.005/h = $3.6/month
# _____
# $6.952981/month

# make tf tests in future
data "aws_availability_zones" "available" {}
data "aws_caller_identity" "current" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.2.0"

  name                    = "fastiv-youth-bot-${var.env_name}"
  cidr                    = var.vpc_cidr
  azs                     = data.aws_availability_zones.available.names
  public_subnets          = var.vpc_public_subnets
  map_public_ip_on_launch = var.auto_assign_public_ip
  private_subnets         = var.vpc_private_subnets
  database_subnets        = var.vpc_database_subnets
  enable_nat_gateway      = var.vpc_enable_nat_gateway
  single_nat_gateway      = var.vpc_single_nat_gateway
  tags                    = var.tags
}

# locals {
#   # ecs endpoint is not required for fargate ecs tasks
#   # 1 vpc_enpoint interface = $0.0105/h (mult by 3 az) -> 22.68$/month
#   # but vpc_enpoint gateways are free, and available only of s3 and dynamodb
#   vpc_endpoints = toset(["secretsmanager", "s3", "ecr.dkr", "ecr.api", "dynamodb"])
# }

resource "aws_security_group" "fargate_task" {
  name        = "Tg-bot-sg-${var.env_name}"
  description = "SG for tg bot fargate service"
  vpc_id      = module.vpc.vpc_id
  egress {
    description      = "Allow all egress"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
  }
  tags = merge(
    { "Name" = "Tg-bot-sg-${var.env_name}" },
    var.tags
  )
}

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

resource "aws_ecs_cluster_capacity_providers" "name" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE_SPOT"]
  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    base              = 1
    weight            = 100
  }
}


locals {
  bot_policies = {
    GetTgBotApiKeyPolicy = {
      effect    = "Allow"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = ["${aws_secretsmanager_secret.api_key.arn}"]
    }
    EcrPolicy = {
      effect = "Allow"
      actions = [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:CompleteLayerUpload",
        "ecr:GetDownloadUrlForLayer",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:UploadLayerPart",
        "ecr:GetAuthorizationToken"
      ]
      resources = ["*"]
    }
    # PutCloudWatchLogs = {
    #   effect = "Allow"
    #   actions = [
    #     "logs:CreateLogGroup",
    #     "logs:CreateLogStream",
    #     "logs:PutLogEvents",
    #     "logs:DescribeLogStreams"
    #   ]
    #   resources = ["*"]
    # }
  }
}

data "aws_iam_policy_document" "assume_role_ecs" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["ecs.amazonaws.com", "ecs-tasks.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "tg_bot" {
  name               = "Tg-bot-${var.env_name}"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.assume_role_ecs.json
  tags = merge(
    { "Description" = "Tg bot IAM Role" },
    var.tags
  )
}

data "aws_iam_policy_document" "tg_bot" {
  for_each = local.bot_policies
  statement {
    effect    = each.value.effect
    actions   = each.value.actions
    resources = each.value.resources
  }
}

resource "aws_iam_policy" "tg_bot" {
  for_each = local.bot_policies
  name     = "${each.key}-${var.env_name}"
  path     = "/"
  policy   = data.aws_iam_policy_document.tg_bot[each.key].json
  tags = merge(
    { "Name" = "${each.key}-${var.env_name} policy" },
    var.tags
  )
}

resource "aws_iam_role_policy_attachment" "tg_bot" {
  for_each   = local.bot_policies
  policy_arn = aws_iam_policy.tg_bot[each.key].arn
  role       = aws_iam_role.tg_bot.name
}


resource "aws_secretsmanager_secret" "api_key" {
  name                    = "Tg-bot-API-key-${var.env_name}"
  description             = "Tg bot api key"
  recovery_window_in_days = 0
}
resource "aws_secretsmanager_secret_version" "api_key" {
  secret_id     = aws_secretsmanager_secret.api_key.id
  secret_string = var.api_key
}

resource "aws_ecs_task_definition" "this" {
  family                   = "Tg-bot-taskdef-${var.env_name}"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256 # the smallest available value
  memory                   = 512 # the smallest available value
  network_mode             = "awsvpc"
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
  execution_role_arn = aws_iam_role.tg_bot.arn
  task_role_arn      = aws_iam_role.tg_bot.arn

  #"image": "registry.hub.docker.com/pandemonic/fastiv-youth-bot:latest",
  #"image": "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/fastiv-bot-test:latest"

  container_definitions = <<CONTAINER_DEFINITION
  [
    {
      "name": "tg-bot",
      "image": "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/fastiv-bot-test:latest",
      "cpu": 256,
      "memory": 512,
      "memoryReservation": 64,
      "essential": true,
      "environment": [{"name": "ENV_TAG", "value": "${var.env_name}"}],
      "secrets": [{
        "name": "TELEGRAM_APITOKEN",
        "valueFrom": "${aws_secretsmanager_secret.api_key.arn}"
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
  platform_version = "1.4.0"

  network_configuration {
    subnets          = module.vpc.public_subnets
    security_groups  = [aws_security_group.fargate_task.id]
    assign_public_ip = true
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
