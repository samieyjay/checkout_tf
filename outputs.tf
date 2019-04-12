# Outputs

output "checkout_elb_name" {
  description = "The name of the ELB"
  value       = "${aws_elb.checkout_elb.name}"
}

output "checkout_elb_dns_name" {
  description = "ELB DNS Name"
  value = "${aws_elb.checkout_elb.dns_name}"
}
