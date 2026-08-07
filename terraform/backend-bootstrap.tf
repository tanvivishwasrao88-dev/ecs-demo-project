# ---------------------------------------------------------------------------
# BOOTSTRAP ONLY. Run this BEFORE anything else, with the S3 backend block
# in versions.tf commented out (local state for this one apply).
#
#   terraform init
#   terraform apply -target=aws_s3_bucket.tf_state -target=aws_dynamodb_table.tf_locks
#
# Then edit the bucket name below into versions.tf's backend block, uncomment
# it, and run `terraform init` again — it will offer to migrate state to S3.
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "tf_state" {
  bucket = "${var.project_name}-tf-state-${data.aws_caller_identity.current.account_id}"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "tf_locks" {
  name         = "terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

data "aws_caller_identity" "current" {}

output "tf_state_bucket_name" {
  value = aws_s3_bucket.tf_state.bucket
}
