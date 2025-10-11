output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.demo.id
}

output "instance_public_ip" {
  description = "Public IP address of demo instance"
  value       = aws_eip.demo.public_ip
}

output "elastic_ip" {
  description = "Elastic IP address (static IP that persists across recreations)"
  value       = aws_eip.demo.public_ip
}

output "instance_public_dns" {
  description = "Public DNS name of demo instance"
  value       = aws_instance.demo.public_dns
}

output "ui_url" {
  description = "URL to access SiriusScan UI"
  value       = "http://${aws_eip.demo.public_ip}:3000"
}

output "api_url" {
  description = "URL to access SiriusScan API"
  value       = "http://${aws_eip.demo.public_ip}:9001"
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.demo.id
}

output "instance_connect_command" {
  description = "AWS Systems Manager Session Manager command to connect to instance"
  value       = "aws ssm start-session --target ${aws_instance.demo.id} --region ${var.aws_region}"
}

output "ssh_connect_command" {
  description = "SSH command to connect to instance (if key_pair_name is configured)"
  value       = var.key_pair_name != "" ? "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_eip.demo.public_ip}" : "SSH not configured - use SSM Session Manager instead"
}

