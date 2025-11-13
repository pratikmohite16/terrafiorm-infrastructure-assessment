data "aws_ami" "al2" {
  most_recent = true
  owners      = ["137112412989"] # Amazon
  filter { name = "name" values = ["amzn2-ami-kernel-5.10-hvm-*-x86_64-gp2"] }
}

resource "aws_iam_role" "ssm" {
  name               = "${var.name}-bastion-ssm"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals { type = "Service" identifiers = ["ec2.amazonaws.com"] }
  }
}

resource "aws_iam_role_policy_attachment" "ssm_managed" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  name = "${var.name}-bastion-profile"
  role = aws_iam_role.ssm.name
}

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.al2.id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [var.sg_bastion_id]
  iam_instance_profile   = aws_iam_instance_profile.ssm.name
  user_data              = <<-EOF
                #!/bin/bash
                yum update -y
                yum install -y postgresql jq
                EOF
  tags = merge(var.tags, { Name = "${var.name}-bastion" })
}

output "bastion_id"  { value = aws_instance.bastion.id }
output "bastion_ip"  { value = aws_instance.bastion.public_ip }
