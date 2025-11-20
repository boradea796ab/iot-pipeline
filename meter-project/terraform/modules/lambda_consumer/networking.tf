resource "aws_security_group" "lambda" {
  name        = "${var.resource_name_prefix}-lambda-sg"
  description = "Security group for Lambda ENIs"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.resource_name_prefix}-lambda-sg"
  }
}
