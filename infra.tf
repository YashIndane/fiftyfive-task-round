#Creating SSH keys for EC2 instance
resource "tls_private_key" "server_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

#
resource "aws_key_pair" "gen_ssh_key" {
  depends_on = [
    tls_private_key.server_ssh_key
  ]
  key_name   = "gen_ssh_key"
  public_key = tls_private_key.server_ssh_key.public_key_openssh

  #Store the private key
  provisioner "local-exec" {
    command = <<-EOT
      echo '${tls_private_key.server_ssh_key.private_key_pem}' > server_ssh_key.pem
      chmod 400 server_ssh_key.pem
    EOT
  }
}

#Create security group for the instance
resource "aws_security_group" "server_sg" {
  name        = "EC2 Nginx Server security group"
  description = "Allow connection from Ansible and Jenkins"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Creating the EC2 server instance
resource "aws_instance" "nginx_server" {
  depends_on = [
    aws_security_group.server_sg,
    aws_key_pair.gen_ssh_key
  ]

  ami                    = "ami-0287a05f0ef0e9d9a"
  instance_type          = "t2.micro"
  subnet_id              = "subnet-0b1382acff5d2930a"
  key_name               = "gen_ssh_key"
  vpc_security_group_ids = [aws_security_group.server_sg.id]

  root_block_device {
    volume_size = "20"
  }

  tags = {
    Name = "Nginx Server"
  }

  provisioner "remote-exec" {
    inline = ["echo Nginx Server ready to configure"]

    connection {
      host        = self.public_ip
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.server_ssh_key.private_key_pem
    }
  }

  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ANSIBLE_ASK_PASS=False ANSIBLE_BECOME_METHOD=sudo ANSIBLE_BECOME_ASK_PASS=False ansible-playbook -u ubuntu -i '${self.public_ip},' --private-key server_ssh_key.pem setup-server.yml --become -v"
  }
}
