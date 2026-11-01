terraform {
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "portfolio"
      ManagedBy = "Terraform"
    }
  }
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project   = "portfolio"
      ManagedBy = "Terraform"
    }
  }
}

module "s3" {
  source = "../modules/s3"

  bucket_name                 = var.bucket_name
  cloudfront_distribution_arn = module.cloudfront.distribution_arn
}

module "acm" {
  source = "../modules/acm"

  providers = {
    aws = aws.us_east_1
  }

  domain_name            = var.domain_name
  validation_record_fqdn = module.route53.validation_record_fqdn
}

module "cloudwatch" {
  source = "../modules/cloudwatch"
  function_name = "portfolio-weekly-requests"
}

module "cloudfront" {
  source = "../modules/cloudfront"

  bucket_name            = module.s3.bucket_name
  bucket_regional_domain = module.s3.bucket_regional_domain
  certificate_arn        = module.acm.validated_certificate_arn
  domain_name            = var.domain_name
}

module "route53" {
  source = "../modules/route53"

  hosted_zone_name          = var.hosted_zone_name
  domain_name               = var.domain_name
  certificate_validation    = module.acm.validation_record
  cloudfront_domain_name    = module.cloudfront.distribution_domain_name
  cloudfront_hosted_zone_id = module.cloudfront.distribution_hosted_zone_id
}

module "iam_publish" {
  source = "../modules/iam/publish"

  bucket_arn                  = module.s3.bucket_arn
  cloudfront_distribution_arn = module.cloudfront.distribution_arn
  deploy_role_name            = var.deploy_role_name
  github_oidc_provider_arn    = var.github_oidc_provider_arn
  github_repository           = var.github_repository
  enable_request_report       = var.enable_request_report
  report_topic_arn            = var.enable_request_report ? module.sns[0].topic_arn : null
  report_function_name        = "portfolio-weekly-requests"
  aws_region                  = var.aws_region
}

module "iam_detect" {
  source = "../modules/iam/detect"
}

module "sns" {
  count  = var.enable_request_report ? 1 : 0
  source = "../modules/sns"

  email_address = var.request_report_email
}

module "lambda" {
  count  = var.enable_request_report ? 1 : 0
  source = "../modules/lambda"

  function_name   = "portfolio-weekly-requests"
  role_arn        = module.iam_publish.report_lambda_role_arn
  topic_arn       = module.sns[0].topic_arn
  distribution_id = module.cloudfront.distribution_id
}

module "evbs" {
  count  = var.enable_request_report ? 1 : 0
  source = "../modules/evbs"

  function_arn = module.lambda[0].function_arn
  role_arn     = module.iam_publish.report_scheduler_role_arn
}