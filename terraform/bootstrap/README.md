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

For a local output log, run `..\terraform-log.ps1 init` instead; the wrapper
also accepts `plan` and `apply` and writes logs under `terraform/log`. Direct
Terraform commands do not produce files there.

If the GitHub OIDC provider already exists in this AWS account, import it before
planning. If another Terraform state manages it, follow the migration procedure
below instead of independently importing it.

```powershell
$AccountId = aws sts get-caller-identity --query Account --output text
terraform import aws_iam_openid_connect_provider.github "arn:aws:iam::$AccountId`:oidc-provider/token.actions.githubusercontent.com"
```

### Migrating a provider from `terraform/main`

Stop automated Terraform workflows and all other operations on both states for
the entire migration. Use the same intended AWS account, backend and Terraform
workspace as the original main deployment and the bootstrap deployment. Confirm
the caller account with `aws sts get-caller-identity` and check both workspaces
with `terraform workspace show`. Back up both states securely (they can contain
secrets); ensure the remote state bucket's versioning is enabled.

1. In `terraform/main`, run `terraform state list`. If it contains
   `module.iam_publish.aws_iam_openid_connect_provider.github[0]`, inspect it:

   ```powershell
   terraform state show 'module.iam_publish.aws_iam_openid_connect_provider.github[0]'
   ```

   Record its ARN, confirm it belongs to the intended account, and ensure the
   main `github_oidc_provider_arn` input is that exact ARN. If this address is
   absent, determine which state owns the provider before continuing.
2. In `terraform/bootstrap`, run `terraform state list`. If the provider is not
   already in this state, import the exact ARN recorded above:

   ```powershell
   terraform import aws_iam_openid_connect_provider.github 'YOUR_PROVIDER_ARN'
   ```

   Verify it with `terraform state show aws_iam_openid_connect_provider.github`.
   Do not proceed if import or verification fails. Both states temporarily
   reference the same resource; do not run plan, apply, or destroy concurrently.
3. Back in `terraform/main`, remove only the old state binding:

   ```powershell
   terraform state rm 'module.iam_publish.aws_iam_openid_connect_provider.github[0]'
   terraform state list
   ```

   This does not delete the AWS provider. Confirm the old address is absent and
   the bootstrap address remains present. The module's `removed` block also
   prevents Terraform from deleting the provider if an older main state is
   applied before this manual removal.
4. Review `terraform plan` in each root. In particular, check for changes to
   the shared OIDC provider's client IDs, thumbprints, and tags in the bootstrap
   plan, and verify that main does not create or delete it. Apply only after
   reviewing all changes; resume automation after the migration is verified.

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

Copy the outputs into GitHub repository secrets:

- `apply_role_arn` -> `TF_APPLY_ROLE_ARN`
- `destroy_role_arn` -> `TF_DESTROY_ROLE_ARN`
- `aws_account_id` -> `AWS_ACCOUNT_ID`
- Set `PORTFOLIO_BUCKET`, `HOSTED_ZONE_ID`, and `TF_STATE_BUCKET` secrets to
  the values used by the main stack. Set the `AWS_REGION` repository variable.
- Ensure the defaults in `terraform/main/variables.tf` match the intended infrastructure configuration for automatic apply and destroy.

The OIDC provider ARN output should match `github_oidc_provider_arn` in the
main stack variables. CloudFront, ACM, and WAF actions require wildcard resource
scopes; review those permissions before applying.
