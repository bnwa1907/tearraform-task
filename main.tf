# Create default VPC if not exists
resource "aws_vpc" "myvpc" {
  cidr_block = "10.10.0.0/16"

}

# Create private subnet for MySQL RDS
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.myvpc.id
  cidr_block        = "10.10.1.0/24"  # Adjust the CIDR block as needed
  availability_zone = "us-east-2a"    # Ensure it's in the same AZ as your public subnet
}

# Create public subnet for frontend and backend
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.myvpc.id
  cidr_block        = "10.10.2.0/24"  # Adjust the CIDR block as needed
  availability_zone = "us-east-2b"    # Ensure it's in the same AZ as your private subnet
}

#Create Internet gateway
resource "aws_internet_gateway" "IG" {
  vpc_id = aws_vpc.myvpc.id
}

#Create Route Table for Public Subnets
resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IG.id
  }

}

#Associate public subnets with routing table
resource "aws_route_table_association" "Public_sub1a_Route_Association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.RT.id
}

# Frontend security group
resource "aws_security_group" "frontend" {
  vpc_id = aws_vpc.myvpc.id

  # Allow inbound traffic from anywhere to the frontend
  ingress {
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow outbound traffic to anywhere
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Backend security group
resource "aws_security_group" "backend" {
  vpc_id = aws_vpc.myvpc.id

  # Allow inbound traffic from anywhere to the backend
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Allow inbound traffic from frontend to backend
  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    security_groups  = [aws_security_group.frontend.id]
  }

  # Allow outbound traffic to anywhere
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# MySQL RDS security group
resource "aws_security_group" "mysql" {
  vpc_id = aws_vpc.myvpc.id

  # Allow inbound traffic from backend to MySQL RDS
  ingress {
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    security_groups  = [aws_security_group.backend.id]
  }

  # Deny all inbound and outbound traffic by default
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "my_db_subnet_group" {
  name        = "my-db-subnet-group"
  description = "My DB Subnet Group"
  subnet_ids  = [aws_subnet.public_subnet.id,aws_subnet.private_subnet.id]
}

resource "aws_db_parameter_group" "mysql8_0_param_group" {
  name   = "my-mysql8-0-param-group"
  family = "mysql8.0"

  parameter {
    name  = "character_set_server"
    value = "utf8"
  }

  parameter {
    name  = "collation_server"
    value = "utf8_general_ci"
  }
}

# Backend machine
resource "aws_instance" "backend" {
  ami                    = "ami-0f5daaa3a7fb3378b"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet.id
  associate_public_ip_address = true
  security_groups        = [aws_security_group.backend.id]
  key_name               = "omar"
  tags = {
    Name = "Backend Machine"
  }
}

# Frontend machine
resource "aws_instance" "frontend" {
  ami                    = "ami-0f5daaa3a7fb3378b"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet.id
  associate_public_ip_address = true
  security_groups        = [aws_security_group.frontend.id]
  key_name               = "omar"
  tags = {
    Name = "Frontend Machine"
  }
}

# MySQL RDS instance
resource "aws_db_instance" "mysql" {
  engine               = "mysql"
  engine_version       = "8.0.35"
  instance_class       = "db.t2.micro"
  allocated_storage    = 10
  storage_type         = "gp2"
  identifier_prefix    = "mysql"
  db_name              = "mydatabase"
  username             = "admin"
  password             = "Password1"
  skip_final_snapshot   = true
  #final_snapshot_identifier = "my-final-snapshot"
  parameter_group_name = aws_db_parameter_group.mysql8_0_param_group.name
  db_subnet_group_name = aws_db_subnet_group.my_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.mysql.id]
  publicly_accessible = false
  

  tags = {
    Name = "MySQL RDS"
  }
}
