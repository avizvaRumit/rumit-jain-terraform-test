provider "aws" {
  region = var.region
}

# To get the latest Amazon linux AMI
data "aws_ssm_parameter" "latest_ami" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

#New VPC
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc-cidr
  enable_dns_hostnames = true
}

#Public subnet A for the VPC we created above.
resource "aws_subnet" "subnet-a" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.subnet-cidr-a
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
}

#Public subnet B for the VPC we created above.
resource "aws_subnet" "subnet-b" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.subnet-cidr-b
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = true
}

#Private subnet C for the VPC we created above.
resource "aws_subnet" "subnet-c" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.subnet-cidr-c
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = false
}

#Private subnet D for the VPC we created above.
resource "aws_subnet" "subnet-d" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.subnet-cidr-d
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = false
}

# Custom route table for the VPC.
resource "aws_route_table" "subnet-route-table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Internet Gateway for the VPC. The VPC require an IGW to communicate over the internet.
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}

# Create route table association of public subnet-a
resource "aws_route_table_association" "subnet-a-route-table-association" {
  subnet_id      = aws_subnet.subnet-a.id
  route_table_id = aws_route_table.subnet-route-table.id
}
# Create route table association of public subnet-b
resource "aws_route_table_association" "subnet-b-route-table-association" {
  subnet_id      = aws_subnet.subnet-b.id
  route_table_id = aws_route_table.subnet-route-table.id
}

# EIP for NAT GW1
resource "aws_eip" "eip_natgw1" {
  count = "1"
}
# NAT gateway1
resource "aws_nat_gateway" "natgateway_1" {
  count         = "1"
  allocation_id = aws_eip.eip_natgw1[count.index].id
  subnet_id     = aws_subnet.subnet-a.id
}
# EIP for NAT GW2
resource "aws_eip" "eip_natgw2" {
  count = "1"
}
# NAT gateway2
resource "aws_nat_gateway" "natgateway_2" {
  count         = "1"
  allocation_id = aws_eip.eip_natgw2[count.index].id
  subnet_id     = aws_subnet.subnet-b.id
}

# Private route table for prv subnet-c
resource "aws_route_table" "prv_sub1_rt" {
  count  = "1"
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgateway_1[count.index].id
  }
}
# Route table association betn prv subnet-c & NAT GW1
resource "aws_route_table_association" "pri_sub1_to_natgw1" {
  count          = "1"
  route_table_id = aws_route_table.prv_sub1_rt[count.index].id
  subnet_id      = aws_subnet.subnet-c.id
}
# Private route table for prv subnet-d
resource "aws_route_table" "prv_sub2_rt" {
  count  = "1"
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgateway_2[count.index].id
  }
}
# Route table association betn prv subnet-d & NAT GW2
resource "aws_route_table_association" "pri_sub2_to_natgw2" {
  count          = "1"
  route_table_id = aws_route_table.prv_sub2_rt[count.index].id
  subnet_id      = aws_subnet.subnet-d.id
}

# Security group for load balancer
resource "aws_security_group" "alb_sg" {
  name        = "alb_sg"
  description = "SG for application load balancer"
  vpc_id      = aws_vpc.vpc.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    description = "HTTP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}
# Create security group for webserver
resource "aws_security_group" "webserver_sg" {
  name        = "webserver_sg"
  description = "SG for web server"
  vpc_id      = aws_vpc.vpc.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    description = "HTTP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    description = "HTTP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}
#Create Launch config
resource "aws_launch_configuration" "webserver-launch-config" {
  name_prefix     = "webserver-launch-config"
  image_id        = data.aws_ssm_parameter.latest_ami.value
  instance_type   = "t2.micro"
  key_name        = var.keyname
  security_groups = [aws_security_group.webserver_sg.id]

  root_block_device {
    volume_type = "gp2"
    volume_size = 10
    encrypted   = true
  }
  ebs_block_device {
    device_name = "/dev/sdf"
    volume_type = "gp2"
    volume_size = 5
    encrypted   = true
  }
  lifecycle {
    create_before_destroy = true
  }
  user_data = filebase64("${path.module}/init_webserver.sh")
}
# Create Auto Scaling Group
resource "aws_autoscaling_group" "ASG-tf" {
  name                 = "ASG-tf"
  desired_capacity     = 2
  max_size             = 4
  min_size             = 2
  force_delete         = true
  depends_on           = [aws_lb.ALB-tf]
  target_group_arns    = [aws_lb_target_group.TG-tf.arn]
  health_check_type    = "EC2"
  launch_configuration = aws_launch_configuration.webserver-launch-config.name
  vpc_zone_identifier  = [aws_subnet.subnet-c.id, aws_subnet.subnet-d.id]
}
# Create Target group
resource "aws_lb_target_group" "TG-tf" {
  name       = "Demo-TargetGroup-tf"
  depends_on = [aws_vpc.vpc]
  port       = 80
  protocol   = "HTTP"
  vpc_id     = aws_vpc.vpc.id
  health_check {
    interval            = 60
    path                = "/index.html"
    port                = 80
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 30
    protocol            = "HTTP"
    matcher             = "200,202"
  }
}
# Create ALB
resource "aws_lb" "ALB-tf" {
  name               = "ALG-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.subnet-a.id, aws_subnet.subnet-b.id]
}
# Create ALB Listener
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.ALB-tf.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.TG-tf.arn
  }
}
