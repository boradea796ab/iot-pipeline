resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-private-rt"
  })
}

resource "aws_route_table" "public" {
  count = local.create_public_resources ? 1 : 0

  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this[0].id
  }

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-public-rt"
  })
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "public" {
  for_each = local.create_public_resources ? aws_subnet.public : {}

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public[0].id
}
