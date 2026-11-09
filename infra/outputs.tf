output "instance_id" { value = aws_instance.k3s.id }

output "connect" {
  value = "aws ssm start-session --target ${aws_instance.k3s.id}"
}

output "argocd_port_forward" {
  value = "aws ssm start-session --target ${aws_instance.k3s.id} --document-name AWS-StartPortForwardingSession --parameters portNumber=30443,localPortNumber=8443"
}
