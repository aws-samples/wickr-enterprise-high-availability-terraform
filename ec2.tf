// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

data "aws_ami" "this" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_instance" "jump_box" {
  subnet_id              = aws_subnet.private_subnets["a"].id
  vpc_security_group_ids = [aws_security_group.jump_box.id]
  iam_instance_profile   = aws_iam_instance_profile.this.id
  ami                    = data.aws_ami.this.id
  instance_type          = "t2.small"
  key_name               = var.ssh_key_name

  tags = {
    Name = "wickr-jump-box"
  }

  user_data                   = file("${path.module}/user_data.sh")
  user_data_replace_on_change = true
}


resource "aws_security_group" "jump_box" {
  description = "Wickr jump box egress only security group"
  vpc_id      = aws_vpc.this.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Wickr Jump Box Security Group"
  }
}

resource "aws_iam_instance_profile" "this" {
  name = "wickr_jump_box_instance_profile"
  role = aws_iam_role.jump_box_role.name
}