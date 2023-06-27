data "aws_secretsmanager_secret_version" "this" {
  depends_on = [aws_secretsmanager_secret_version.this]
  secret_id  = aws_secretsmanager_secret.this.id
}

resource "aws_rds_cluster" "this" {
  skip_final_snapshot    = true
  cluster_identifier     = "wickrdb"
  database_name          = "wickrdb"
  engine                 = "aurora-mysql"
  master_username        = "admin"
  master_password        = jsondecode(data.aws_secretsmanager_secret_version.this.secret_string)["password"]
  storage_encrypted      = true
  kms_key_id             = aws_kms_key.db.arn
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
}

resource "aws_db_subnet_group" "this" {
  description = "RDS Aurora MySQL Subnet Group for Wickr Enterprise"
  subnet_ids = [
    aws_subnet.private_subnets["a"].id,
    aws_subnet.private_subnets["b"].id,
    aws_subnet.private_subnets["c"].id
  ]
}

resource "aws_security_group" "db" {
  description = "Wickr database security group"
  vpc_id      = aws_vpc.this.id
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.this.vpc_config[0].cluster_security_group_id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Wickr Database Security Group"
  }
}

resource "aws_rds_cluster_instance" "this" {
  count                = 3
  cluster_identifier   = aws_rds_cluster.this.id
  instance_class       = "db.r5.large"
  engine               = "aurora-mysql"
  publicly_accessible  = false
  db_subnet_group_name = aws_db_subnet_group.this.name
}

