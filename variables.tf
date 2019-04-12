variable "aws_region" {}
variable "aws_access_key" {}
variable "aws_secret_key" {}
data "aws_availability_zones" "available" {}
variable "localip" {}
variable "vpc_cidr" {}

variable "cidrs" {
  type = "map"
}

variable "key_name" {}
variable "public_key_path" {}
variable "base_image_instance_type" {}
variable "base_image_ami" {}
variable "elb_healthy_threshold" {}
variable "elb_unhealthy_threshold" {}
variable "elb_timeout" {}
variable "elb_interval" {}
variable "asg_max" {}
variable "asg_min" {}
variable "asg_grace" {}
variable "asg_hct" {}
variable "asg_dc" {}
variable "launch_template_instance_type" {}
