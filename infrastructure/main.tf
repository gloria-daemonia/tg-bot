# make tf tests in future
data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.2.0"

  name               = "fastiv-youth-bot-${var.env_name}"
  cidr               = var.vpc_cidr
  azs                = data.aws_availability_zones.available.names
  public_subnets     = var.vpc_public_subnets
  private_subnets    = var.vpc_private_subnets
  database_subnets   = var.vpc_database_subnets
  enable_nat_gateway = var.vpc_enable_nat_gateway
  single_nat_gateway = var.vpc_single_nat_gateway
  tags               = var.tags
}

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


locals {
  bot_policies = {
    GetTgBotApiKeyPolicy = {
      effect    = "Allow"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = ["api_key_secret_arn"]
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
  family                   = "Tg-bot-${var.env_name}"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 64
  memory                   = 64
  network_mode             = "awsvpc"
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
  execution_role_arn = aws_iam_role.tg_bot.arn
  task_role_arn      = aws_iam_role.tg_bot.arn

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
  platform_version = "LATEST"

  network_configuration {
    subnets          = module.vpc.public_subnets
    security_groups  = [aws_security_group.fargate_task.id]
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
