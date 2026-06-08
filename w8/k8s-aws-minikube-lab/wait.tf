resource "null_resource" "wait_for_app" {
  depends_on = [
    aws_lb_listener.http,
    aws_lb_target_group_attachment.app
  ]

  triggers = {
    instance_id    = aws_instance.minikube.id
    user_data_hash = filesha256("${path.module}/user-data.sh")
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = aws_instance.minikube.public_ip
    private_key = tls_private_key.ssh.private_key_pem
    timeout     = "10m"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for cloud-init to finish...'",
      "sudo cloud-init status --wait",
      "echo 'Checking app on EC2 local port ${var.app_node_port}...'",
      "for i in $(seq 1 60); do curl -fsS http://127.0.0.1:${var.app_node_port}/ >/dev/null 2>&1 && echo 'App is ready.' && exit 0; sleep 5; done",
      "echo 'App did not become ready in time.' >&2",
      "sudo tail -n 120 /var/log/user-data.log || true",
      "exit 1"
    ]
  }
}
