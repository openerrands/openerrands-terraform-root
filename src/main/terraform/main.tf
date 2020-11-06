terraform {
  backend "s3" {
    // From backend.config or command line
    encrypt = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.13.0"
    }
  }
}

provider "aws" {
  profile = "openerrands_root_ci"
  region = var.region
}

resource "aws_organizations_organization" "root" {}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "root_cloudtrail" {
  statement {
    actions   = ["s3:GetBucketAcl"]
    resources = ["arn:aws:s3:::${var.global_prefix}-root-logging"]
    principals {
      type = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }

  statement {
    actions = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${var.global_prefix}-root-logging/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
    principals {
      type = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test = "StringEquals"
      variable = "s3:x-amz-acl"
      values = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket" "root_logging" {
  bucket = "${var.global_prefix}-root-logging"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "root_logging" {
  bucket = aws_s3_bucket.root_logging.id

  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "root_logging" {
  bucket = aws_s3_bucket.root_logging.id
  policy = data.aws_iam_policy_document.root_cloudtrail.json
}

resource "aws_cloudtrail" "root_logging" {
  name = "logging"
  s3_bucket_name = aws_s3_bucket.root_logging.bucket
  include_global_service_events = true
}



resource "aws_organizations_organizational_unit" "environments" {
  for_each = toset(var.environments)
  name = each.key
  parent_id = aws_organizations_organization.root.roots[0].id
}

resource "aws_organizations_account" "accounts" {
  for_each = toset(var.environments)
  name = "root-${each.key}"
  email = "aws+root-${each.key}@openerrands.cloud"
  parent_id = aws_organizations_organizational_unit.environments[each.key].id
}

resource "aws_iam_group" "root_ci" {
  name = "ci"
  path = "/infrastructure/"
}

resource "aws_iam_group_policy_attachment" "root_ci_admin" {
  group = aws_iam_group.root_ci.id
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

data "aws_iam_policy_document" "root_ci_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    resources = [ for environment in var.environments : "arn:aws:iam::${aws_organizations_account.accounts[environment].id}:role/OrganizationAccountAccessRole" ]
  }
}

resource "aws_iam_policy" "root_ci_assume_role" {
  name = "CIAssumeRole"
  policy = data.aws_iam_policy_document.root_ci_assume_role.json
}

resource "aws_iam_group_policy_attachment" "root_ci_org_unit_admin" {
  for_each = toset(var.environments)
  group = aws_iam_group.root_ci.id
  policy_arn = aws_iam_policy.root_ci_assume_role.arn
}

resource "aws_iam_user" "root_ci" {
  name = "ci"
  path = "/infrastructure/"
}

resource "aws_iam_access_key" "root_ci" {
  user = aws_iam_user.root_ci.id
}

resource "aws_iam_group_membership" "root_ci" {
  name = "root_ci_group_membership"
  group = aws_iam_group.root_ci.name
  users = [
    aws_iam_user.root_ci.name
  ]
}