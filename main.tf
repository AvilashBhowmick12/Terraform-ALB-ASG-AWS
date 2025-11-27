
provider "aws" {
  region = "us-west-1"
}

data "aws_vpc" "default" {
  id = "vpc-0d2627eac5e0e37f9"
}

data "aws_subnet" "az1" {
  availability_zone = "us-west-1a"
  vpc_id            = data.aws_vpc.default.id
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_security_group" "existing_sg" {
  filter {
    name   = "group-name"
    values = ["launch-wizard-18"]
  }
  vpc_id = data.aws_vpc.default.id
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_launch_template" "this" {
  name_prefix   = "${var.web_app}-lt"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.web_instance_type
  key_name      = var.web_key_name

  vpc_security_group_ids = [data.aws_security_group.existing_sg.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd git
    systemctl start httpd
    systemctl enable httpd
    cd /var/www/html
    git clone https://github.com/AvilashBhowmick12/Terraform-ALB-ASG-AWS.git
    cd Terraform-ALB-ASG-AWS
    FILE=$(ls *.html | shuf -n 1)
    cp $FILE /var/www/html/index.html
  EOF
  )
}

resource "aws_autoscaling_group" "this" {
  name                      = "${var.web_app}-asg"
  max_size                  = var.web_max_size
  min_size                  = var.web_min_size
  desired_capacity          = var.web_desired_capacity
  vpc_zone_identifier       = [data.aws_subnet.az1.id]
  health_check_type         = "EC2"
  force_delete              = true

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    triggers = ["launch_template"]
  }

  tag {
    key                 = "Name"
    value               = "from-terra"
    propagate_at_launch = true
  }
}

resource "aws_lb" "this" {
  name               = "${var.web_app}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [data.aws_security_group.existing_sg.id]
  subnets            = data.aws_subnets.default.ids

  tags = {
    Terraform = "true"
  }
}

resource "aws_lb_target_group" "this" {
  name     = "${var.web_app}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
}

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

resource "aws_autoscaling_attachment" "this" {
  autoscaling_group_name = aws_autoscaling_group.this.id
  lb_target_group_arn    = aws_lb_target_group.this.arn
}
