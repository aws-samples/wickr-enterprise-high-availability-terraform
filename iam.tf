resource "aws_iam_role" "eks_cluster_role" {
  name = "WickrEKSClusterRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"]
}

resource "aws_iam_role" "eks_node_role" {
  name = "WickrEKSNodeRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  ]
  inline_policy {
    name = "s3Policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "s3:PutObject",
            "s3:GetObject",
            "s3:DeleteObject",
            "s3:AbortMultipartUpload",
            "s3:GetObjectVersion",
            "s3:ListMultipartUploadParts"
          ]
          Effect   = "Allow"
          Resource = "${aws_s3_bucket.wickr_files_bucket.arn}/*"
        }
      ]
    })
  }
}

resource "aws_iam_role" "eks_admin_role" {
  name = "WickrEKSAdminRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
      },
    ]
  })
  inline_policy {
    name = "IAMandEKS"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "iam:GetRole",
            "iam:ListRoles",
            "iam:CreateServiceLinkedRole",
            "iam:PassRole"
          ]
          Effect   = "Allow"
          Resource = aws_iam_role.eks_cluster_role.arn
        },
        {
          Action = [
            "eks:Create*",
            "eks:Associate*",
            "eks:RegisterCluster",
            "eks:TagResource",
            "eks:Update*"
          ]
          Effect   = "Allow"
          Resource = aws_eks_cluster.this.arn
        }
      ]
    })
  }
}

resource "aws_iam_role" "jump_box_role" {
  name = "WickrJumpBoxRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
  inline_policy {
    name = "AssumeEKSAdmin"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = ["sts:AssumeRole"]
          Effect   = "Allow"
          Resource = aws_iam_role.eks_admin_role.arn
        }
      ]
    })
  }
}
