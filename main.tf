provider "aws" {
  region = "us-east-1"
}

# 1- Create VPC
resource "aws_vpc" "stage-vpc" {
  cidr_block       = "10.0.0.0/16"
  
  tags = {
    Name = "Stage"
  }
}
# 2- Create Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.stage-vpc.id

  tags = {
    Name = "Stage"
  }
}
# 3- Create custom Route Table
resource "aws_route_table" "stage-route-table" {
  vpc_id = aws_vpc.stage-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Stage"
  }
}
# 4- Create a subnet
resource "aws_subnet" "subnet-1" {
  vpc_id     = aws_vpc.stage-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Stage-Subnet"
  }
}
# 5- Associate subnet with Route Table association
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.stage-route-table.id
}
# 6-  Create Security Group to allo por 22,80,443
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.stage-vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
   }
  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
   }
  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
   }
   ingress {
    description      = "ICMP"
    from_port        = 8
    to_port          = -1
    protocol         = "icmp"
    cidr_blocks      = ["0.0.0.0/0"]
   }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
   }

  tags = {
    Name = "allow_web_traffic"
  }
}
# 7- Create a network interface with an ip the subnet that was create in step 4
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}
# 8- Assign an elastic IP to the network interface created in step 7
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]
}

# 9- Create Ubuntu server an install/enable apache2
resource "aws_instance" "web-server-instance"{
  ami = "ami-04505e74c0741db8d"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"  
  key_name = aws_key_pair.stage.id

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo Mi first server web using Terraform > /var/www/html/index.html'
              EOF
  tags = {
    Name = "Web-Server"
  }
}

resource "aws_key_pair" "stage" {
  key_name   = "key_stage"
  public_key = "Aqui va tu key pair"
}
output "instance_ips" {
  value = aws_instance.web-server-instance.*.public_ip
}
