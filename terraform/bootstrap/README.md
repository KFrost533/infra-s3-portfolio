# GitHub Actions bootstrap

This root owns the portfolio bucket, its versioning and public access block,
the GitHub OIDC provider and the separate Terraform apply and destroy roles.
These resources remain available when `terraform/main` is destroyed. The state
bucket is created and protected separately; this root uses its own key in that
bucket.

## Prerequisites

- Create `tf-kfrost533` in `ap-southeast-2` outside this state. Enable versioning
  and encryption, block public access, and restrict access.
- Use an AWS administrator or equivalent local credentials for the initial
  bootstrap. Do not use the GitHub roles being created here to bootstrap them.
- Copy `terraform.tfvars.example` to an untracked `terraform.tfvars` and set the
  existing hosted zone ID and bucket names.
- For an existing portfolio bucket, complete the migration below before applying
  either root; otherwise bootstrap will try to create a bucket that already exists.

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

### Migrating an existing portfolio bucket

Stop the scheduled and manual apply, destroy and upload workflows, wait for
running jobs to finish, and stop all other Terraform operations on both states
for the entire migration. Verify the AWS account, region, workspaces, backends,
and matching `portfolio_bucket_name` and main `bucket_name` inputs. Securely
back up both state files and confirm state bucket versioning is enabled.

1. In `terraform/main`, check `terraform state list`. Confirm the bucket,
   versioning and public access block exist at
   `module.s3.aws_s3_bucket.portfolio`,
   `module.s3.aws_s3_bucket_versioning.portfolio` and
   `module.s3.aws_s3_bucket_public_access_block.portfolio`. Check the bucket
   name with `terraform state show module.s3.aws_s3_bucket.portfolio` and
   confirm it matches the intended existing bucket.
2. In `terraform/bootstrap`, run `terraform init` and inspect
   `terraform state list`. If an address already exists, verify it refers to
   the intended bucket; do not import a second object at that address.
   Import any missing addresses with the same bucket name:

   ```powershell
   $Bucket = "YOUR_EXISTING_PORTFOLIO_BUCKET"
   terraform import aws_s3_bucket.portfolio $Bucket
   terraform import aws_s3_bucket_public_access_block.portfolio $Bucket
   terraform import aws_s3_bucket_versioning.portfolio $Bucket
   ```

   Verify all three with `terraform state show`. Both states temporarily
   reference the same objects; do not run plan, apply or destroy concurrently.
   Stop if any import or verification fails.
3. In `terraform/main`, remove only the three old state bindings:

   ```powershell
   terraform state rm 'module.s3.aws_s3_bucket.portfolio'
   terraform state rm 'module.s3.aws_s3_bucket_public_access_block.portfolio'
   terraform state rm 'module.s3.aws_s3_bucket_versioning.portfolio'
   ```

   These commands do not delete AWS resources. Verify the old addresses are
   absent from main and all three are present in bootstrap. The main module's
   `removed` blocks also prevent deletion if main is applied before manual
   removal, but bootstrap must still import the existing objects.
4. Review plans in both roots. Bootstrap must not create, replace or destroy the
   existing bucket, versioning, or public access block; investigate any changes
   before applying. Main must read the existing bucket rather than create or
   delete it. Once the migration and plans are verified, resume the workflows.

The bucket policy remains in main because it refers to the current CloudFront
distribution. Destroying main removes that policy, including its HTTPS-only
deny, while bootstrap continues to enforce the bucket's public access block.

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
project infrastructure, but the portfolio bucket is owned by bootstrap and
protected from deletion by the main destroy workflow. Both roles trust only
this repository's `main` branch subject. The state bucket and bootstrap state
are not accessible to either GitHub role except the main state's object and
lockfile paths.

Copy the outputs into GitHub repository secrets:

- `apply_role_arn` -> `TF_APPLY_ROLE_ARN`
- `destroy_role_arn` -> `TF_DESTROY_ROLE_ARN`
- `aws_account_id` -> `AWS_ACCOUNT_ID`
- Set `AWS_REGION`, `PORTFOLIO_BUCKET`, `HOSTED_ZONE_ID`, and `TF_STATE_BUCKET`
  secrets to the values used by the main stack.
- Ensure the defaults in `terraform/main/variables.tf` match the intended infrastructure configuration for automatic apply and destroy.

The OIDC provider ARN output should match `github_oidc_provider_arn` in the
main stack variables. CloudFront, ACM, and WAF actions require wildcard resource
scopes; review those permissions before applying.
