terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region     = "us-east-1"
  access_key = "AKIAIOSFODNN7EXAMPLE"          # FLAW: hardcoded credentials
  secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"  # FLAW: hardcoded credentials
}

# FLAW: S3 bucket is public and unencrypted, no versioning
resource "aws_s3_bucket" "data" {
  bucket = "iac-test-flawed-bucket"
}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket                  = aws_s3_bucket.data.id
  block_public_acls       = false  # FLAW: should be true
  block_public_policy     = false  # FLAW: should be true
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# FLAW: security group open to the world on SSH and RDP
resource "aws_security_group" "wide_open" {
  name        = "wide-open-sg"
  description = "Intentionally overly permissive for testing"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]   # FLAW: SSH open to internet
  }

  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]   # FLAW: RDP open to internet
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# FLAW: RDS instance publicly accessible, unencrypted, weak password
resource "aws_db_instance" "flawed" {
  identifier          = "iac-test-db"
  engine              = "mysql"
  instance_class      = "db.t3.micro"
  allocated_storage   = 20
  username            = "admin"
  password            = "password123"      # FLAW: hardcoded weak password
  publicly_accessible = true               # FLAW: should be false
  storage_encrypted   = false              # FLAW: should be true
  skip_final_snapshot = true
}

# FLAW: IAM policy with wildcard action and resource
resource "aws_iam_policy" "overly_permissive" {
  name = "overly-permissive-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "*"        # FLAW: wildcard action
        Resource = "*"        # FLAW: wildcard resource
      }
    ]
  })
}

# FLAW: unencrypted EBS volume
resource "aws_ebs_volume" "unencrypted" {
  availability_zone = "us-east-1a"
  size              = 10
  encrypted         = false   # FLAW: should be true
}

# NOTE: this bucket IS correctly configured (control case, should NOT be flagged)
resource "aws_s3_bucket" "secure_control" {
  bucket = "iac-test-secure-bucket"
}

resource "aws_s3_bucket_public_access_block" "secure_control" {
  bucket                  = aws_s3_bucket.secure_control.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "secure_control" {
  bucket = aws_s3_bucket.secure_control.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
