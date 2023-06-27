data "aws_arn" "jump_box_arn" {
  arn = aws_instance.jump_box.arn
}

output "instance_id" {
  value = trimprefix(data.aws_arn.jump_box_arn.resource, "instance/")
}

output "database_endpoint" {
  value = aws_rds_cluster.this.endpoint
}

output "s3_bucket_name" {
  value = aws_s3_bucket.wickr_files_bucket.id
}

output "eks_admin_role_arn" {
  value = aws_iam_role.eks_admin_role.arn
}