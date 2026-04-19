provider "aws" {
  region                      = "us-east-1"
  access_key                  = "mock_access_key"
  secret_key                  = "mock_secret_key"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints { 
    ec2 = "http://localhost:4566"
  }
}

# 1. Create vpc

resource "aws_vpc" "testing-vpc" {
  cidr_block = "10.0.0.0/16"
  tags ={
    Name = "testing"
  }
}

# 2. Create Internet Gateway

resource "aws_internet_gateway" "main-gateway" {
  vpc_id = aws_vpc.testing-vpc.id
}

# 3. Create Custom Route Table

resource "aws_route_table" "testing-route-table" {
  vpc_id = aws_vpc.testing-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main-gateway.id
  }
  
  route {
    ipv6_cidr_block        = "::/0"
    gateway_id             = aws_internet_gateway.main-gateway.id
  }
  
  tags ={
    Name = "testing"
  }
}

# 4. Create a Subnet 

resource "aws_subnet" "testing-subnet" {
  vpc_id     = aws_vpc.testing-vpc.id
  cidr_block = "10.0.1.0/24"
  tags ={
    Name = "testing"
  }
}

# 5. Associate Subnet With Route Table

resource "aws_route_table_association" "testing-route-table-association" {
  subnet_id      = aws_subnet.testing-subnet.id
  route_table_id = aws_route_table.testing-route-table.id
}

# 6. Create Security Group to allow Port 22,80,443

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.testing-vpc.id
  tags ={
    Name = "allow_web"
  }
}

resource "aws_vpc_security_group_ingress_rule" "HTTPS" {
  security_group_id = aws_security_group.allow_web.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "HTTP" {
  security_group_id = aws_security_group.allow_web.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "SSH" {
  security_group_id = aws_security_group.allow_web.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic" {
  security_group_id = aws_security_group.allow_web.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# 7. Create a Network Interface With an IP in the Subnet that Was Created in Step 4

resource "aws_network_interface" "web-server" {
  subnet_id = aws_subnet.testing-subnet.id
  private_ips = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
  
}

# 8. Assign an Elastic IP to the Network Interface Created in Step 7 (We are on Localstack so we will not use Elastic IP but we will use the private IP instead)

# resource "aws_eip" "one" {
#   domain            = "vpc"
#   network_interface = aws_network_interface.web-server.id
#   associate_with_private_ip = "10.0.1.50" 
#   depends_on = [aws_internet_gateway.main-gateway]
# }

# output "value" {
#   value = aws_eip.one.public_ip
# }

# 9. Create Ubuntu Server and 

resource "aws_instance" "web-server-instance" {
  ami = "ami-085925f297f89fce1"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  # subnet_id = aws_subnet.testing-subnet.id
  
  # the new way we add (subnet_id) step and we remove these 4 lines and add (aws_network_interface_attach) step

  network_interface {  
    device_index = 0
    network_interface_id = aws_network_interface.web-server.id
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systmectl start apache2
              sudo bash -c 'echo your very first web server > /var/www/html/index.html'
              EOF
  tags ={
    Name = "web-server"
  }
}

# resource "aws_network_interface_attachment" "nic_attach" {
#   instance_id = aws_instance.web-server-instance.id
#   network_interface_id = aws_network_interface.web-server.id
#   device_index = 1
# }