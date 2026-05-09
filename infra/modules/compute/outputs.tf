output "instance_a_id" {
  description = "Instance A (CW agent host) EC2 ID"
  value       = aws_instance.instance_a.id
}

output "instance_b_id" {
  description = "Instance B (isolated target) EC2 ID"
  value       = aws_instance.instance_b.id
}

output "instance_a_private_ip" {
  description = "Instance A private IP"
  value       = aws_instance.instance_a.private_ip
}

output "instance_b_private_ip" {
  description = "Instance B private IP"
  value       = aws_instance.instance_b.private_ip
}
