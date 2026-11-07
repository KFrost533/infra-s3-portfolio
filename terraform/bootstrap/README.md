# GitHub Actions bootstrap

This root owns the GitHub OIDC provider and the separate Terraform apply and
destroy roles. These resources must remain available when `terraform/main` is
destroyed. The state bucket is created and protected separately; this root uses
its own key in that bucket.

## Prerequisites

- Create `tf-kfrost533` in `ap-southeast-2` outside this state. Enable versioning
  and encryption, block public access, and restrict access.
- Use an AWS administrator or equivalent local credentials for the initial
  bootstrap. Do not use the GitHub roles being created here to bootstrap them.
- Copy `terraform.tfvars.example` to an untracked `terraform.tfvars` and set the
  existing hosted zone ID and bucket names.

## Apply

From this directory:

```powershell
terraform init
```

If the GitHub OIDC provider already exists in this AWS account, import it before
planning. This adopts it into the bootstrap state instead of trying to create a
duplicate:

```powershell
$AccountId = aws sts get-caller-identity --query Account --output text
terraform import aws_iam_openid_connect_provider.github "arn:aws:iam::$AccountId`:oidc-provider/token.actions.githubusercontent.com"
```

Then review and apply:

```powershell
terraform plan
terraform apply
```

Actions use service-level wildcards, scoped to the project's resources where
the AWS service supports resource-level permissions. The apply workflow blocks
plans containing deletes or replacements; the separate destroy role can delete
project infrastructure and portfolio bucket versions. Both roles trust only
this repository's `main` branch subject. The state bucket and bootstrap state
are not accessible to either GitHub role except the main state's object and
lockfile paths.

Copy the outputs into GitHub repository variables:

- `apply_role_arn` -> `TF_APPLY_ROLE_ARN`
- `destroy_role_arn` -> `DESTROY_ROLE_ARN`
- `aws_account_id` -> `AWS_ACCOUNT_ID` and `DESTROY_AWS_ACCOUNT_ID`
- Set `AWS_REGION`, `PORTFOLIO_BUCKET`, and `TF_HOSTED_ZONE_ID` to the values
  used by the main stack.
- Keep `TF_VARS_JSON` as a GitHub secret for `terraform/main` inputs.

The OIDC provider ARN output should match `github_oidc_provider_arn` in the
main stack variables. CloudFront, ACM, and WAF actions require wildcard resource
scopes; review those permissions before applying.
