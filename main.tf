provider "aws" {
  region = "eu-west-1"  # Replace with your desired AWS region
  shared_credentials_files = ["$HOME/.aws/credentials"]
  profile = "ch-innovation"
  #profile = "default"
  }

resource "aws_vpc" "demo-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "net-vpc"
  }
}

resource "aws_subnet" "private-subnet-1" {
  vpc_id     = aws_vpc.demo-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-west-1a"
  tags = {
    Name = "private-subnet-1"
  }
}

resource "aws_subnet" "private-subnet-2" {
  vpc_id     = aws_vpc.demo-vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "eu-west-1b"
  tags = {
    Name = "private-subnet-2"
  }
}

resource "aws_subnet" "public-subnet-1" {
  vpc_id     = aws_vpc.demo-vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "eu-west-1a"
  tags = {
    Name = "public-subnet-1"
  }
}

resource "aws_subnet" "public-subnet-2" {
  vpc_id     = aws_vpc.demo-vpc.id
  cidr_block = "10.0.4.0/24"
  availability_zone = "eu-west-1b"
  tags = {
    Name = "public-subnet-2"
  }
}

resource "aws_internet_gateway" "demo-igw" {
  vpc_id = aws_vpc.demo-vpc.id
  tags = {
    Name = "demo-vpc-IGW"
    }
}

resource "aws_route_table" "public-route-table" {
  vpc_id = aws_vpc.demo-vpc.id
  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route" "public-route" {
  route_table_id         = aws_route_table.public-route-table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.demo-igw.id
}

resource "aws_route_table_association" "public-subnet-1-association" {
  subnet_id      = aws_subnet.public-subnet-1.id
  route_table_id = aws_route_table.public-route-table.id
}

resource "aws_route_table_association" "public-subnet-2-association" {
  subnet_id      = aws_subnet.public-subnet-2.id
  route_table_id = aws_route_table.public-route-table.id
}

resource "aws_eip" "nat-eip" {
  domain = "vpc"
   tags = {
      Name = "nat-eip"
      }
}

resource "aws_nat_gateway" "nat-gateway" {
  allocation_id = aws_eip.nat-eip.id
  subnet_id     = aws_subnet.public-subnet-1.id
  tags = {
      Name = "nat-gateway"
      }
}

resource "aws_security_group" "web-sg" {
  vpc_id = aws_vpc.demo-vpc.id
  name   = "web-sg"

  ingress {
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

  tags = {
    Name = "web-sg"
  }
}

resource "aws_security_group" "dns-inbound-endpoint-sg" {
  vpc_id = aws_vpc.demo-vpc.id
  name   = "dns-sg"

  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dns-inbound-endpoint-sg"
  }
}

resource "aws_security_group" "db-sg" {
  vpc_id = aws_vpc.demo-vpc.id
  name   = "db-sg"

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24", "10.0.2.0/24"]  
    # Allow traffic from private subnets
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "db-sg"
  }
}


resource "aws_instance" "private-instance" {
  ami           = "ami-0b53285ea6c7a08a7"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private-subnet-1.id
  tags = {
    Name = "private-instance"
  }
}

resource "aws_instance" "public-instance" {
  ami           = "ami-053a617c6207ecc7b"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public-subnet-1.id
  user_data = <<-EOF
  #!/bin/bash
  echo "*** Installing apache2"
  sudo apt update -y
  sudo apt install apache2 -y
  echo "*** Completed Installing apache2"
  EOF
  tags = {
    Name = "public-instance"
  }
}

resource "aws_route53_zone" "private" {
  name = "cohogov.co.uk"

  vpc {
    vpc_id = aws_vpc.demo-vpc.id
  }
}

resource "aws_route53_resolver_endpoint" "foo" {
  name      = "foo"
  direction = "INBOUND"

  security_group_ids = [
    aws_security_group.dns-inbound-endpoint-sg.id
  ]

  ip_address {
    subnet_id = aws_subnet.private-subnet-1.id
  }

  ip_address {
    subnet_id = aws_subnet.private-subnet-2.id
    ip        = "10.0.2.4"
  }

  protocols = ["Do53"]

  tags = {
    Environment = "Innovation"
  }
}