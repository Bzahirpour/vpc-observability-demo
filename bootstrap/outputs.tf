output "tf_state_bucket" {
  description = "S3 bucket name for Terraform remote state — use this in infra/envs/*/backend.tf"
  value       = aws_s3_bucket.tf_state.id
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions — paste into .github/workflows/terraform.yml AWS_ROLE_ARN"
  value       = aws_iam_role.github_actions.arn
}

output "aws_account_id" {
  description = "AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "github_oidc_provider_arn" {
  description = "ARN of the shared GitHub Actions OIDC provider"
  value       = data.aws_iam_openid_connect_provider.github.arn
}
