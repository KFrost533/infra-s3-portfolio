mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

mock_provider "aws" {
  alias = "us_east_1"
}

run "waf_disabled_by_default" {
  command = plan

  assert {
    condition     = length(module.waf) == 0 && output.waf_web_acl_arn == null
    error_message = "The optional WAF must be absent by default."
  }
}

run "waf_enabled_in_count_mode" {
  command = plan

  variables {
    enable_waf = true
  }

  assert {
    condition     = length(module.waf) == 1
    error_message = "Enabling WAF must create a CloudFront-scoped web ACL."
  }
}

run "waf_module_counts_requests" {
  command = plan

  module {
    source = "./modules/waf"
  }

  assert {
    condition     = aws_wafv2_web_acl.portfolio.scope == "CLOUDFRONT"
    error_message = "The web ACL must be CloudFront-scoped."
  }

  assert {
    condition = (
      length(aws_wafv2_web_acl.portfolio.default_action[0].allow) == 1 &&
      length(one(aws_wafv2_web_acl.portfolio.rule).override_action[0].count) == 1 &&
      one(aws_wafv2_web_acl.portfolio.rule).statement[0].managed_rule_group_statement[0].name == "AWSManagedRulesCommonRuleSet"
    )
    error_message = "The managed rule group must count requests and the default action must allow them."
  }
}

run "cloudfront_accepts_web_acl" {
  command = plan

  module {
    source = "./modules/cloudfront"
  }

  variables {
    bucket_name            = "portfolio-test-bucket"
    bucket_regional_domain = "portfolio-test-bucket.s3.us-east-1.amazonaws.com"
    certificate_arn        = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
    domain_name            = "portfolio.example.com"
    web_acl_arn            = "arn:aws:wafv2:us-east-1:123456789012:global/webacl/test/00000000-0000-0000-0000-000000000000"
  }

  assert {
    condition     = aws_cloudfront_distribution.portfolio.web_acl_id == var.web_acl_arn
    error_message = "CloudFront must associate the supplied web ACL ARN."
  }
}
