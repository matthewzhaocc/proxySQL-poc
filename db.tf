// selling my soul to aws again
provider "aws" {
  region = "us-west-1"
}

// variable for db password
variable "db_pass" {
  type = string
}
// the subnet group
resource "aws_db_subnet_group" "proxysqlpoc" {
    name = "proxysqlpoc"
    subnet_ids = [aws_subnet.a.id, aws_subnet.b.id]
}
// primary db
resource "aws_db_instance" "primary" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mariadb"
  engine_version       = "10.4.8"
  instance_class       = "db.t3.medium"
  name                 = "proxysqlpoc"
  username             = "admin"
  password             = var.db_pass
  parameter_group_name = "default.mariadb10.4"
  apply_immediately    = true
  // stupid read replica requirements
  backup_retention_period = 3
  //enable multiaz
  multi_az = true
  // db subnet group setting
  db_subnet_group_name = aws_db_subnet_group.proxysqlpoc.name
  skip_final_snapshot = true
}
// read replica 1
resource "aws_db_instance" "rr1" {
    replicate_source_db = aws_db_instance.primary.id
    storage_type = "gp2"
    engine = "mariadb"
    engine_version = "10.4.8"
    instance_class = "db.t3.medium"
    name = "rr1-proxysqlpoc"
    username = "admin"
    password = var.db_pass
    parameter_group_name = "default.mariadb10.4"
    apply_immediately = true
    // stupid read replica requirements
    backup_retention_period = 3
    db_subnet_group_name = aws_db_subnet_group.proxysqlpoc.name
    skip_final_snapshot = true
}

// proxysql server vpc
resource "aws_vpc" "proxysql_vpc" {
    cidr_block = "10.69.0.0/16"
    instance_tenancy = "default"
}
// subnets
resource "aws_subnet" "a" {
    vpc_id = aws_vpc.proxysql_vpc.id
    cidr_block = "10.69.0.0/24"
    map_public_ip_on_launch = true
    availability_zone_id = "usw1-az1"
}

resource "aws_subnet" "b" {
    vpc_id = aws_vpc.proxysql_vpc.id
    cidr_block = "10.69.1.0/24"
    map_public_ip_on_launch = true
    availability_zone_id = "usw1-az3"
}

resource "aws_internet_gateway" "igw1" {
    vpc_id = aws_vpc.proxysql_vpc.id
}

resource "aws_route_table" "r" {
    vpc_id = aws_vpc.proxysql_vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw1.id
    }
}

