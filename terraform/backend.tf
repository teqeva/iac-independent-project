terraform {
  backend "s3" {
    bucket         = "iac-project-tfstate-327936092308"
    key            = "iac-independent-project/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "iac-project-tf-locks"
    encrypt        = true
  }
}
