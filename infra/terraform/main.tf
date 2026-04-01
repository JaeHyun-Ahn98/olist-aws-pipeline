terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# S3 버킷 (Data Lake)
resource "aws_s3_bucket" "olist_data_lake" {
  bucket = "${var.project_name}-data-lake-${var.account_id}"

  tags = {
    Project = var.project_name
    Env     = "dev"
  }
}

# S3 버킷 버전관리
resource "aws_s3_bucket_versioning" "olist_data_lake" {
  bucket = aws_s3_bucket.olist_data_lake.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Redshift 서브넷 그룹
resource "aws_redshift_subnet_group" "olist" {
  name       = "${var.project_name}-subnet-group"
  subnet_ids = [aws_subnet.olist_subnet.id]
}

# VPC
resource "aws_vpc" "olist_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# 서브넷
resource "aws_subnet" "olist_subnet" {
  vpc_id            = aws_vpc.olist_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "${var.project_name}-subnet"
  }
}

# Redshift 보안 그룹
resource "aws_security_group" "redshift_sg" {
  name   = "${var.project_name}-redshift-sg"
  vpc_id = aws_vpc.olist_vpc.id

  ingress {
    from_port   = 5439
    to_port     = 5439
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

 # Glue가 VPC 안에서 실행될 때 필요한 self 규칙
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Redshift 클러스터
resource "aws_redshift_cluster" "olist" {
  cluster_identifier  = "${var.project_name}-cluster"
  database_name       = "olistdb"
  master_username     = var.redshift_username
  master_password     = var.redshift_password
  node_type           = "ra3.xlplus"
  cluster_type        = "single-node"
  skip_final_snapshot = true

  cluster_subnet_group_name = aws_redshift_subnet_group.olist.name
  vpc_security_group_ids    = [aws_security_group.redshift_sg.id]

  publicly_accessible = true

  tags = {
    Project = var.project_name
  }
}

# 인터넷 게이트웨이 — VPC가 외부 인터넷과 통신할 수 있게
resource "aws_internet_gateway" "olist_igw" {
  vpc_id = aws_vpc.olist_vpc.id

  tags = { Name = "${var.project_name}-igw" }
}

# 라우팅 테이블 — 외부 트래픽을 인터넷 게이트웨이로 보내도록
resource "aws_route_table" "olist_rt" {
  vpc_id = aws_vpc.olist_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.olist_igw.id
  }

  tags = { Name = "${var.project_name}-rt" }
}

# 라우팅 테이블을 서브넷에 연결
resource "aws_route_table_association" "olist_rta" {
  subnet_id      = aws_subnet.olist_subnet.id
  route_table_id = aws_route_table.olist_rt.id
}

# S3 VPC 엔드포인트 — Glue가 VPC 안에서 S3 접근할 수 있게
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.olist_vpc.id
  service_name = "com.amazonaws.ap-northeast-2.s3"
  route_table_ids = [aws_route_table.olist_rt.id]

  tags = {
    Name = "${var.project_name}-s3-endpoint"
  }
}