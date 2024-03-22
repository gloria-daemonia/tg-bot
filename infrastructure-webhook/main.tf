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

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "fastiv-youth-bot-lambda-role-${var.env_name}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

}

resource "aws_lambda_function" "this" {
  function_name = "fastiv-youth-bot-${var.env_name}"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "provided.al2023"
  s3_bucket     = "pandemonic-fastiv-youth-bot-tf-state"
  s3_key        = "${var.env_name}/bot-code/bootstrap"
}

resource "aws_lambda_function_url" "this" {
  function_name      = aws_lambda_function.this
  authorization_type = "NONE"
  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["*"]
    allow_headers     = ["date", "keep-alive"]
    expose_headers    = ["keep-alive", "date"]
    max_age           = 0
  }
}
# aws_lambda_function_url.this.function_url = https://<url_id>.lambda-url.<region>.on.aws
# url_id - A generated ID for the endpoint.
