output "public_ip" {
  value = aws_spot_instance_request.k3s_node.public_ip
}

output "jenkins_url" {
  value = "http://jenkins.ybtest.pics"
}

output "grafana_url" {
  value = "http://grafana.ybtest.pics"
}

output "ssh_command" {
  value = "ssh -i <your-key.pem> ubuntu@${aws_spot_instance_request.k3s_node.public_ip}"
}