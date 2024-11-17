provider "aws" {
  region = var.region
}
provider "aws" {
  alias = "us-east-1"
  region = "us-east-1"
  
}
provider "random" {}

data "aws_caller_identity" "current" {}