provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "my_bucket" {
  bucket = "praveenchaudhary230389" # bucket name must be globally unique
}
