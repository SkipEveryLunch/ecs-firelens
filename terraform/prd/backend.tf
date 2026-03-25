// MEMO: 開発中はローカルバックエンドで作業する
// S3移行時は下記「tfstateをS3に移行する」手順を参照
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

// S3バックエンド（本番運用時に切り替え）
// ★ bucket/profile は variables.tf の tfstate_bucket/aws_profile と同じ値にすること
//
// terraform {
//   backend "s3" {
//     bucket  = "REPLACE_ME_TFSTATE_BUCKET"
//     key     = "main.tfstate"
//     region  = "ap-northeast-1"
//     profile = "REPLACE_ME_AWS_PROFILE"
//   }
// }
