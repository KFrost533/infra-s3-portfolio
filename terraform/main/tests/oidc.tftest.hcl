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

run "main_rejects_null_oidc_provider" {
  command = plan

  variables {
    github_oidc_provider_arn = null
  }

  expect_failures = [var.github_oidc_provider_arn]
}

run "publish_uses_bootstrap_provider" {
  command = plan

  module {
    source = "../modules/iam/publish"
  }

  variables {
    bucket_arn                  = "arn:aws:s3:::portfolio-test"
    cloudfront_distribution_arn = "arn:aws:cloudfront::123456789012:distribution/TEST"
    deploy_role_name            = "portfolio-test"
    github_oidc_provider_arn    = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
    github_repository           = "example/portfolio"
    github_repository_owner_id  = "123"
    github_repository_id        = "456"
  }

  assert {
    condition     = one(one(data.aws_iam_policy_document.github_trust.statement).principals).identifiers == toset([var.github_oidc_provider_arn])
    error_message = "The deployment role must trust the supplied bootstrap OIDC provider."
  }
}

run "legacy_provider_in_main_state" {
  command   = apply
  state_key = "oidc_migration"

  module {
    source = "./tests/fixtures/legacy_oidc"
  }

  assert {
    condition     = length(aws_iam_openid_connect_provider.github) == 1
    error_message = "The migration fixture must start with a managed OIDC provider."
  }
}

run "forget_legacy_provider" {
  command   = apply
  state_key = "oidc_migration"

  module {
    source = "../modules/iam/publish"
  }

  variables {
    bucket_arn                  = "arn:aws:s3:::portfolio-test"
    cloudfront_distribution_arn = "arn:aws:cloudfront::123456789012:distribution/TEST"
    deploy_role_name            = "portfolio-test"
    github_oidc_provider_arn    = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
    github_repository           = "example/portfolio"
    github_repository_owner_id  = "123"
    github_repository_id        = "456"
  }

  assert {
    condition     = one(one(data.aws_iam_policy_document.github_trust.statement).principals).identifiers == toset([var.github_oidc_provider_arn])
    error_message = "The deployment role must still trust the bootstrap OIDC provider after migration."
  }
}
