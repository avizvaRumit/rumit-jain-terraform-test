output "latest_ami_id" {
  value = data.aws_ssm_parameter.latest_ami.value
}
# Display ELB IP address

output "elb_dns_name" {
  value = aws_lb.ALB-tf.dns_name
}