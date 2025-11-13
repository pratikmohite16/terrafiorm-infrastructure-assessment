resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = merge(var.tags, { Name = "${var.name}-vpc" })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-igw" })
}

# 2 public + 2 private subnets (multi-AZ)
resource "aws_subnet" "public" {
  for_each = { for i, az in toset(var.azs) : i => az }
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.cidr, 4, each.key)
  availability_zone       = each.value
  map_public_ip_on_launch = true
  tags = merge(var.tags, { Name = "${var.name}-public-${each.value}", Tier = "public" })
}

resource "aws_subnet" "private" {
  for_each = { for i, az in toset(var.azs) : i => az }
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.cidr, 4, each.key + 8)
  availability_zone = each.value
  tags = merge(var.tags, { Name = "${var.name}-private-${each.value}", Tier = "private" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-rtb-public" })
}

resource "aws_route" "public_inet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

output "vpc_id"               { value = aws_vpc.this.id }
output "public_subnet_ids"    { value = [for s in aws_subnet.public : s.id] }
output "private_subnet_ids"   { value = [for s in aws_subnet.private : s.id] }
