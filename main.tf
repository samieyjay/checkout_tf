provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region  = "${var.aws_region}"
}

#data "aws_availability_zones" "available" {}

#-------------VPC-----------

resource "aws_vpc" "checkout_vpc" {
  cidr_block           = "${var.vpc_cidr}"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags {
    Name = "checkout_vpc"
  }
}

#internet gateway

resource "aws_internet_gateway" "checkout_igw" {
  vpc_id = "${aws_vpc.checkout_vpc.id}"

  tags {
    Name = "checkout_igw"
  }
}

# Route tables

resource "aws_route_table" "checkout_public_rt" {
  vpc_id = "${aws_vpc.checkout_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.checkout_igw.id}"
  }

  tags {
    Name = "checkout_public"
  }
}

resource "aws_default_route_table" "checkout_private_rt" {
  default_route_table_id = "${aws_vpc.checkout_vpc.default_route_table_id}"

  tags {
    Name = "checkout_private"
  }
}

resource "aws_subnet" "checkout_public_subnet1" {
  vpc_id                  = "${aws_vpc.checkout_vpc.id}"
  cidr_block              = "${var.cidrs["public1"]}"
  map_public_ip_on_launch = true
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"

  tags {
    Name = "checkout_public1"
  }
}

resource "aws_subnet" "checkout_public_subnet2" {
  vpc_id                  = "${aws_vpc.checkout_vpc.id}"
  cidr_block              = "${var.cidrs["public2"]}"
  map_public_ip_on_launch = true
  availability_zone       = "${data.aws_availability_zones.available.names[1]}"

  tags {
    Name = "checkout_public2"
  }
}

resource "aws_subnet" "checkout_private_subnet1" {
  vpc_id                  = "${aws_vpc.checkout_vpc.id}"
  cidr_block              = "${var.cidrs["private1"]}"
  map_public_ip_on_launch = false
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"

  tags {
    Name = "checkout_private1"
  }
}

resource "aws_subnet" "checkout_private_subnet2" {
  vpc_id                  = "${aws_vpc.checkout_vpc.id}"
  cidr_block              = "${var.cidrs["private2"]}"
  map_public_ip_on_launch = false
  availability_zone       = "${data.aws_availability_zones.available.names[1]}"

  tags {
    Name = "checkout_private2"
  }
}

# Subnet Associations

resource "aws_route_table_association" "checkout_public_assoc" {
  subnet_id      = "${aws_subnet.checkout_public_subnet1.id}"
  route_table_id = "${aws_route_table.checkout_public_rt.id}"
}

resource "aws_route_table_association" "checkout_public2_assoc" {
  subnet_id      = "${aws_subnet.checkout_public_subnet2.id}"
  route_table_id = "${aws_route_table.checkout_public_rt.id}"
}

resource "aws_route_table_association" "checkout_private1_assoc" {
  subnet_id      = "${aws_subnet.checkout_private_subnet1.id}"
  route_table_id = "${aws_default_route_table.checkout_private_rt.id}"
}

resource "aws_route_table_association" "checkout_private2_assoc" {
  subnet_id      = "${aws_subnet.checkout_private_subnet2.id}"
  route_table_id = "${aws_default_route_table.checkout_private_rt.id}"
}

#Security groups

resource "aws_security_group" "checkout_base_image_sg" {
  name        = "checkout_base_image_sg"
  description = "Used for access to the base_image instance"
  vpc_id      = "${aws_vpc.checkout_vpc.id}"

  #SSH

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.localip}"]
  }

  #HTTP

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${var.localip}"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Public Security group

resource "aws_security_group" "checkout_public_sg" {
  name        = "checkout_public_sg"
  description = "Used for public and private instances for load balancer access"
  vpc_id      = "${aws_vpc.checkout_vpc.id}"

  #HTTP 

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #Outbound internet access

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Private Security Group

resource "aws_security_group" "checkout_private_sg" {
  name        = "checkout_private_sg"
  description = "Used for private instances"
  vpc_id      = "${aws_vpc.checkout_vpc.id}"

  # Access from other security groups

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${var.vpc_cidr}"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#---------compute-----------

#key pair

resource "aws_key_pair" "checkout_auth" {
  key_name   = "${var.key_name}"
  public_key = "${file(var.public_key_path)}"
}

#base_image server

resource "aws_instance" "checkout_base_image" {
  instance_type = "${var.base_image_instance_type}"
  ami           = "${var.base_image_ami}"

  tags {
    Name = "checkout_base_image"
  }

  key_name               = "${aws_key_pair.checkout_auth.id}"
  vpc_security_group_ids = ["${aws_security_group.checkout_base_image_sg.id}"]
  subnet_id              = "${aws_subnet.checkout_public_subnet1.id}"

  provisioner "local-exec" {
    command = <<EOD
cat <<EOF > hosts 
[base_image] 
${aws_instance.checkout_base_image.public_ip} 
EOF
EOD
  }

  provisioner "local-exec" {
    command = "aws ec2 wait instance-status-ok --instance-ids ${aws_instance.checkout_base_image.id} --profile default && ansible-playbook -i hosts lamp.yml"
  }
}

#load balancer

resource "aws_elb" "checkout_elb" {
  name = "checkout-elb"

  subnets = ["${aws_subnet.checkout_public_subnet1.id}",
    "${aws_subnet.checkout_public_subnet2.id}",
  ]

  security_groups = ["${aws_security_group.checkout_public_sg.id}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = "${var.elb_healthy_threshold}"
    unhealthy_threshold = "${var.elb_unhealthy_threshold}"
    timeout             = "${var.elb_timeout}"
    target              = "TCP:80"
    interval            = "${var.elb_interval}"
  }

  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags {
    Name = "checkout-elb"
  }
}

#AMI 

resource "random_id" "golden_ami" {
  byte_length = 8
}

resource "aws_ami_from_instance" "checkout_golden" {
  name               = "checkout_ami-${random_id.golden_ami.b64}"
  source_instance_id = "${aws_instance.checkout_base_image.id}"

  provisioner "local-exec" {
    command = <<EOT
cat <<EOF > userdata.sh
#!/bin/bash
/bin/touch /var/spool/cron/root
sudo /bin/echo '*/10 * * * * git pull origin/master /var/www/html/' >> /var/spool/cron/root
EOF
EOT
  }
}

#launch template

resource "aws_launch_template" "checkout_lc" {
  name_prefix = "checkout_lc-"
  image_id = "${aws_ami_from_instance.checkout_golden.id}"
  instance_type = "${var.launch_template_instance_type}"
  vpc_security_group_ids      = ["${aws_security_group.checkout_private_sg.id}"]
  key_name = "${aws_key_pair.checkout_auth.id}" 
  user_data = "${base64encode(file("userdata.sh"))}"
}

resource "aws_autoscaling_group" "checkout_asg" {
  name                      = "asg-checkout"
  max_size                  = "${var.asg_max}"
  min_size                  = "${var.asg_min}"
  health_check_grace_period = "${var.asg_grace}"
  health_check_type         = "${var.asg_hct}"
  desired_capacity          = "${var.asg_dc}"
  force_delete              = true
  load_balancers            = ["${aws_elb.checkout_elb.id}"]

  vpc_zone_identifier = ["${aws_subnet.checkout_private_subnet1.id}",
    "${aws_subnet.checkout_private_subnet2.id}",
  ]


  launch_template {
    id      = "${aws_launch_template.checkout_lc.id}"
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "checkout_asg-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}
