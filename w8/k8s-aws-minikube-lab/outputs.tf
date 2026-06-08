output "alb_url" {
  description = "Public URL to access the app through ALB"
  value       = "http://${aws_lb.app.dns_name}"
}

output "ec2_public_ip" {
  description = "Public IP of EC2 running Minikube"
  value       = aws_instance.minikube.public_ip
}

output "ssh_command" {
  description = "SSH command to access EC2"
  value       = "ssh -i ${var.project_name}.pem ubuntu@${aws_instance.minikube.public_ip}"
}

output "check_app_from_ec2" {
  description = "Command to test the app inside EC2"
  value       = "curl http://127.0.0.1:${var.app_node_port}/"
}
