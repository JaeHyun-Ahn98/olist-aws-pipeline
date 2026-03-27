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
  node_type           = "dc2.large"
  cluster_type        = "single-node"
  skip_final_snapshot = true

  cluster_subnet_group_name = aws_redshift_subnet_group.olist.name
  vpc_security_group_ids    = [aws_security_group.redshift_sg.id]

  publicly_accessible = true

  tags = {
    Project = var.project_name
  }
}