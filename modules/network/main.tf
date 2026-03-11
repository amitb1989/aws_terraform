resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(var.tags, { Name = "${var.name}-vpc" })
}

data "aws_availability_zones" "available" {}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-igw" })
}

# Public subnets + RTs
# resource "aws_subnet" "public" {
#   for_each = { for idx, cidr in var.public_subnet_cidrs : idx => { cidr = cidr, az = data.aws_availability_zones.available.names[idx] } }
#   vpc_id                  = aws_vpc.this.id
#   cidr_block              = each.value.cidr
#   availability_zone       = each.value.az
#   map_public_ip_on_launch = true
#   tags = merge(var.tags, { Name = "${var.name}-public-${each.key}" })
# }



resource "aws_subnet" "public" {
  for_each = {
    for idx, cidr in var.public_subnet_cidrs :
    idx => { cidr = cidr, az = data.aws_availability_zones.available.names[idx] }
  }

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-public-${each.key}"
      "kubernetes.io/role/elb" = "1"
      "kubernetes.io/cluster/eks-cluster-assement" = "shared"
    }
  )
}


resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-public-rt" })
}

resource "aws_route" "public_igw" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# NAT per AZ for HA
resource "aws_eip" "nat" {
  for_each = aws_subnet.public
  domain   = "vpc"
  tags     = merge(var.tags, { Name = "${var.name}-nat-eip-${each.key}" })
}

resource "aws_nat_gateway" "nat" {
  for_each      = aws_subnet.public
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id
  tags          = merge(var.tags, { Name = "${var.name}-nat-${each.key}" })
}

# Private subnets + RTs (each AZ -> its NAT)
# resource "aws_subnet" "private" {
#   for_each = { for idx, cidr in var.private_subnet_cidrs : idx => { cidr = cidr, az = data.aws_availability_zones.available.names[idx] } }
#   vpc_id            = aws_vpc.this.id
#   cidr_block        = each.value.cidr
#   availability_zone = each.value.az
#   tags = merge(var.tags, { Name = "${var.name}-private-${each.key}" })
# }


resource "aws_subnet" "private" {
  for_each = {
    for idx, cidr in var.private_subnet_cidrs :
    idx => { cidr = cidr, az = data.aws_availability_zones.available.names[idx] }
  }

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-private-${each.key}"
      "kubernetes.io/role/internal-elb" = "1"
      "kubernetes.io/cluster/eks-cluster-assement" = "shared"
    }
  )
}


resource "aws_route_table" "private" {
  for_each = aws_subnet.private
  vpc_id   = aws_vpc.this.id
  tags     = merge(var.tags, { Name = "${var.name}-private-rt-${each.key}" })
}

resource "aws_route" "private_nat" {
  for_each               = aws_route_table.private
  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[each.key].id
}

resource "aws_route_table_association" "private_assoc" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

output "vpc_id"              { value = aws_vpc.this.id }
output "public_subnet_ids"   { value = [for s in values(aws_subnet.public) : s.id] }
output "private_subnet_ids"  { value = [for s in values(aws_subnet.private) : s.id] }
