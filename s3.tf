### Files Bucket ###

resource "aws_s3_bucket" "wickr_files_bucket" {
  bucket = "wickr-files-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
}

resource "aws_s3_bucket_versioning" "wickr_files_bucket" {
  bucket = aws_s3_bucket.wickr_files_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_logging" "wickr_files_bucket" {
  bucket = aws_s3_bucket.wickr_files_bucket.id

  target_bucket = aws_s3_bucket.wickr_logging_bucket.id
  target_prefix = "wickr-ha"
}

resource "aws_s3_bucket_policy" "wickr_files_bucket" {
  bucket = aws_s3_bucket.wickr_files_bucket.id
  policy = jsonencode(
    {
      Version = "2012-10-17"
      Statement = [
        {
          Sid       = "Only Allow Secure Transport"
          Action    = "s3:*"
          Effect    = "Deny"
          Principal = "*"
          Resource = [
            "arn:${data.aws_partition.current.partition}:s3:::wickr-files-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}",
            "arn:${data.aws_partition.current.partition}:s3:::wickr-files-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}/*"
          ]
          Condition = {
            Bool = {
              "aws:SecureTransport" = ["false"]
            }
          }

        }
      ]

  })
}

### Logging Bucket ###

resource "aws_s3_bucket" "wickr_logging_bucket" {
  bucket = "wickr-logs-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
}

resource "aws_s3_bucket_versioning" "wickr_logging_bucket" {
  bucket = aws_s3_bucket.wickr_logging_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "wickr_logging_bucket" {
  bucket = aws_s3_bucket.wickr_logging_bucket.id

  rule {
    id     = "GlacierRule"
    status = "Enabled"

    transition {
      days          = 180
      storage_class = "GLACIER"
    }

    expiration {
      days = 730
    }
  }
}

resource "aws_s3_bucket_policy" "wickr_logging_bucket" {
  bucket = aws_s3_bucket.wickr_logging_bucket.id
  policy = jsonencode(
    {
      Version = "2012-10-17"
      Statement = [
        {
          Sid       = "Only Allow Secure Transport"
          Action    = "s3:*"
          Effect    = "Deny"
          Principal = "*"
          Resource = [
            "arn:${data.aws_partition.current.partition}:s3:::wickr-logs-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}",
            "arn:${data.aws_partition.current.partition}:s3:::wickr-logs-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}/*"
          ]
          Condition = {
            Bool = {
              "aws:SecureTransport" = ["false"]
            }
          }

        },
        {
          Sid    = "Allow S3 Server Access Logging"
          Action = "s3:PutObject"
          Effect = "Allow"
          Principal = {
            Service = "logging.s3.amazonaws.com"
          }
          Resource = [
            "arn:${data.aws_partition.current.partition}:s3:::wickr-logs-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}/*"
          ]
        }
      ]

  })
}