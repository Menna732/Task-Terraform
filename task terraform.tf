# provider to determinate which cloud prodiver I will used 
provider "aws" {
  region = "us-east-1" 
  
}
# the first steps to creat init ,plan and apply 
#front-end tier 
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.2.0/24"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my_vpc.id
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id
}

resource "aws_eip" "nat_eip" {
  vpc = true
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.my_vpc.id
}

resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}
#back-end tier 
# Security Group for Backend Tier
resource "aws_security_group" "backend_sg" {
  name        = "backend-sg"
  description = "Allow backend layer communication"
  vpc_id      = aws_vpc.main.id

  # Allow traffic from Frontend Security Group
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.frontend_sg.id] # Link to Frontend SG
  }

  # Allow all egress (outbound traffic)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "backend-sg"
  }
}

# Backend EC2 Instances
resource "aws_instance" "backend" {
  count         = 2 # Launch 2 instances
  ami           = "ami-0c55b159cbfafe1f0" 
  instance_type = "t2.micro"
  security_groups = [aws_security_group.backend_sg.id]

  }

#database tier
# Security Group for Database
resource "aws_security_group" "database_sg" {
  name        = "database_sg"
  description = "Security Group for the database tier"
  vpc_id      = aws_vpc.main.id

  # Allow traffic from Backend tier
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.backend_sg.id]
  }

  # Allow only outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "database_sg"
  }
}

# RDS Instance
resource "aws_db_instance" "database" {
  nchar_character_set_name = "database"
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  username             = "admin"
  password             = "password123" # Replace with a stronger password
  vpc_security_group_ids = [aws_security_group.database_sg.id]
  db_subnet_group_name = aws_db_subnet_group.db_subnet_group.name

  skip_final_snapshot = true

  tags = {
    Name = "my-rds-instance"
  }
}

# Subnet Group for RDS
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "db-subnet-group"
  description = "Subnet group for RDS"
  subnet_ids = [
    aws_subnet.private_subnet_1.id,
    aws_subnet.private_subnet_2.id
  ]

  tags = {
    Name = "db-subnet-group"
  }
}

# note : terraform when I write terraform init run but 
# plan and apply not run I think because I do't have a sercet key and a Access key 