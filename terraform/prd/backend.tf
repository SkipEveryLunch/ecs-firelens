// ★ bucket/profile は variables.tf の tfstate_bucket/aws_profile と同じ値にすること
terraform {
  backend "s3" {
    bucket  = "REPLACE_ME_TFSTATE_BUCKET"
    key     = "main.tfstate"
    region  = "ap-northeast-1"
    profile = "REPLACE_ME_AWS_PROFILE"
  }
}
