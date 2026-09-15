output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main.id
}

output "web_instance_ids" {
  description = "EC2 instance IDs"
  value       = aws_instance.web[*].id
}

output "web_public_ips" {
  description = "Public IP addresses of the web servers"
  value       = aws_instance.web[*].public_ip
}

output "web_public_dns" {
  description = "Public DNS names of the web servers"
  value       = aws_instance.web[*].public_dns
}

output "web_urls" {
  description = "Browser URLs for verification"
  value       = [for ip in aws_instance.web[*].public_ip : "http://${ip}"]
}

output "ssh_commands" {
  description = "Ready-to-paste SSH commands"
  value       = [for ip in aws_instance.web[*].public_ip : "ssh -i ~/.ssh/iac-project


