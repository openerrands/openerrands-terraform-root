output "iam_root_ci_access_key" {
  value = var.secrets ? aws_iam_access_key.root_ci.id : null
}
output "iam_root_ci_secret_key" {
  value = var.secrets ? aws_iam_access_key.root_ci.secret : null
}