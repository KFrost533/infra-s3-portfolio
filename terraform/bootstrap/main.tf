terraform {
  required_version = ">= 1.10.0"

  backend "s3" {
    bucket       = "tf-kfrost533"
    key          = "portfolio-bootstrap/terraform.tfstate"
    region       = "ap-southeast-2"
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id           = data.aws_caller_identity.current.account_id
  partition            = data.aws_partition.current.partition
  owner                = split("/", var.github_repository)[0]
  repository           = split("/", var.github_repository)[1]
  oidc_sub             = "repo:${local.owner}@${var.github_repository_owner_id}/${local.repository}@${var.github_repository_id}:ref:refs/heads/main"
  portfolio_bucket_arn = "arn:${local.partition}:s3:::${var.portfolio_bucket_name}"
  state_bucket_arn     = "arn:${local.partition}:s3:::${var.state_bucket_name}"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1b511abead59c6ce207077c0bf0e0043b1382612"]
}

module "github_actions_roles" {
  source = "./roles"

  aws_region                     = var.aws_region
  partition                      = local.partition
  account_id                     = local.account_id
  oidc_provider_arn              = aws_iam_openid_connect_provider.github.arn
  oidc_subject                   = local.oidc_sub
  apply_role_name                = var.apply_role_name
  destroy_role_name              = var.destroy_role_name
  deploy_role_name               = var.deploy_role_name
  report_function_name           = var.report_function_name
  state_bucket_arn               = local.state_bucket_arn
  portfolio_bucket_arn           = local.portfolio_bucket_arn
  hosted_zone_id                 = var.hosted_zone_id
  request_report_email_parameter = var.request_report_email_parameter
}
