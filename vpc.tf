resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr_range
  enable_dns_hostnames = true
  tags = {
    Name : "wickr-ha"
  }
}

### PUBLIC SUBNETS ###

resource "aws_subnet" "public_subnets" {
  for_each                = var.public_subnets
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = "${data.aws_region.current.name}${each.key}"
  map_public_ip_on_launch = true

  tags = {
    Name = "wickr-ha-public-${each.key}"
  }
}

### PRIVATE SUBNETS ###

resource "aws_subnet" "private_subnets" {
  for_each          = var.private_subnets
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = "${data.aws_region.current.name}${each.key}"

  tags = {
    Name = "wickr-ha-private-${each.key}"
  }
}

### GATEWAYS ###

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "wickr-ha"
  }
}

resource "aws_nat_gateway" "this" {
  for_each      = var.public_subnets
  allocation_id = aws_eip.this[each.key].id
  subnet_id     = aws_subnet.public_subnets[each.key].id
}

resource "aws_eip" "this" {
  for_each = var.public_subnets
  domain   = "vpc"

  tags = {
    Name = "wickr-ha-nat-eip-${each.key}"
  }
}

### PUBLIC ROUTING ###

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "wickr-ha-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  for_each       = var.public_subnets
  subnet_id      = aws_subnet.public_subnets[each.key].id
  route_table_id = aws_route_table.public.id
}

### PRIVATE ROUTING ###

resource "aws_route_table" "private" {
  for_each = var.private_subnets
  vpc_id   = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[each.key].id
  }

  tags = {
    Name = "wickr-ha-private-rt-${each.key}"
  }
}

resource "aws_route_table_association" "private" {
  for_each       = var.private_subnets
  subnet_id      = aws_subnet.private_subnets[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}