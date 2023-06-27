resource "aws_kms_key" "secretsmanager" {
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "*"
        Resource = "*"
        Effect   = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
      },
    ]
  })
}

resource "aws_kms_alias" "secretsmanager" {
  name          = "alias/wickr_dbpassword"
  target_key_id = aws_kms_key.secretsmanager.id
}

resource "aws_kms_key" "db" {
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "*"
        Resource = "*"
        Effect   = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
      },
    ]
  })
}

resource "aws_kms_alias" "db" {
  name          = "alias/wickr_dbstorage"
  target_key_id = aws_kms_key.db.id
}