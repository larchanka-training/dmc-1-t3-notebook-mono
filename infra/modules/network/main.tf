locals {
  public_subnet_cidrs      = [for index, _ in var.availability_zones : cidrsubnet(var.vpc_cidr, 4, index)]
  private_app_subnet_cidrs = [for index, _ in var.availability_zones : cidrsubnet(var.vpc_cidr, 4, index + length(var.availability_zones))]
  private_db_subnet_cidrs  = [for index, _ in var.availability_zones : cidrsubnet(var.vpc_cidr, 4, index + (2 * length(var.availability_zones)))]
  nat_gateway_map          = var.nat_gateway_mode == "per-az" ? { for index, az in var.availability_zones : az => index } : { (var.availability_zones[0]) = 0 }
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpc"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-igw"
  })
}

resource "aws_subnet" "public" {
  for_each = { for index, az in var.availability_zones : az => index }

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = local.public_subnet_cidrs[each.value]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-${each.key}"
    Tier = "public"
  })
}

resource "aws_subnet" "private_app" {
  for_each = { for index, az in var.availability_zones : az => index }

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = local.private_app_subnet_cidrs[each.value]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-app-${each.key}"
    Tier = "application"
  })
}

resource "aws_subnet" "private_db" {
  for_each = { for index, az in var.availability_zones : az => index }

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = local.private_db_subnet_cidrs[each.value]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-db-${each.key}"
    Tier = "database"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  for_each = local.nat_gateway_map

  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-eip-${each.key}"
  })
}

resource "aws_nat_gateway" "this" {
  for_each = local.nat_gateway_map

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = values(aws_subnet.public)[each.value].id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-${each.key}"
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "private_app" {
  for_each = { for index, az in var.availability_zones : az => index }

  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = var.nat_gateway_mode == "per-az" ? aws_nat_gateway.this[each.key].id : aws_nat_gateway.this[var.availability_zones[0]].id
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-app-rt-${each.key}"
  })
}

resource "aws_route_table_association" "private_app" {
  for_each = aws_subnet.private_app

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_app[each.key].id
}

resource "aws_route_table" "private_db" {
  for_each = aws_subnet.private_db

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-db-rt-${each.key}"
  })
}

resource "aws_route_table_association" "private_db" {
  for_each = aws_subnet.private_db

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_db[each.key].id
}
