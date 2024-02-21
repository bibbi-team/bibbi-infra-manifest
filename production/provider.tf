terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
  backend "s3" {
    bucket         = "bibbi-tfstate"
    key            = "terraform/bibbi-prod/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "bibbi-terraform-lock"
  }
}

provider "aws" {
  region = "ap-northeast-2"
}
