resource "aws_eks_cluster" "this" {
  name     = "wickr-ha"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = var.eks_version
  vpc_config {
    subnet_ids = [
      aws_subnet.public_subnets["a"].id,
      aws_subnet.public_subnets["b"].id,
      aws_subnet.public_subnets["c"].id,
      aws_subnet.private_subnets["a"].id,
      aws_subnet.private_subnets["b"].id,
      aws_subnet.private_subnets["c"].id
    ]
    endpoint_private_access = true
    endpoint_public_access  = true
  }
  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator"
  ]
}

resource "aws_security_group_rule" "udp_ingress" {
  type              = "ingress"
  protocol          = "udp"
  from_port         = 16384
  to_port           = 17384
  cidr_blocks       = [var.public_ingress_cidr]
  security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

resource "aws_security_group_rule" "https_ingress_public" {
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_blocks       = [var.public_ingress_cidr]
  security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

resource "aws_security_group_rule" "https_ingress_jump_box" {
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 443
  to_port                  = 443
  source_security_group_id = aws_security_group.jump_box.id
  security_group_id        = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

resource "aws_security_group_rule" "socks_ingress" {
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 8001
  to_port           = 8001
  cidr_blocks       = [var.public_ingress_cidr]
  security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}



resource "aws_eks_node_group" "worker" {
  cluster_name    = aws_eks_cluster.this.id
  node_group_name = "worker_node_group"
  instance_types  = ["m5.2xlarge"]
  scaling_config {
    min_size     = 2
    desired_size = 3
    max_size     = 5
  }
  subnet_ids = [
    aws_subnet.private_subnets["a"].id,
    aws_subnet.private_subnets["b"].id,
    aws_subnet.private_subnets["c"].id
  ]
  disk_size     = 50
  node_role_arn = aws_iam_role.eks_node_role.arn

  # allow for autoscaling to take place outside of Terraform
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

resource "aws_eks_node_group" "calling" {
  cluster_name    = aws_eks_cluster.this.id
  node_group_name = "calling_node_group"
  instance_types  = ["m5.2xlarge"]
  scaling_config {
    min_size     = 2
    desired_size = 3
    max_size     = 5
  }
  subnet_ids = [
    aws_subnet.public_subnets["a"].id,
    aws_subnet.public_subnets["b"].id,
    aws_subnet.public_subnets["c"].id
  ]
  disk_size     = 50
  node_role_arn = aws_iam_role.eks_node_role.arn
  labels = {
    "role" : "calling"
  }

  # allow for autoscaling to take place outside of Terraform
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.this.id
  addon_name   = "vpc-cni"
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.this.id
  addon_name   = "coredns"

  # fails to build without worker nodes
  depends_on = [
    aws_eks_node_group.calling,
    aws_eks_node_group.worker
  ]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.this.id
  addon_name   = "kube-proxy"
}