terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

resource "aws_wafv2_web_acl" "portfolio" {
  name        = "portfolio-web-acl"
  description = "Observe common web threats to the portfolio without blocking requests."
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 0

    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "PortfolioCommonRules"
      sampled_requests_enabled   = false
    }
  }  

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "PortfolioWebACL"
    sampled_requests_enabled   = false
  }
}