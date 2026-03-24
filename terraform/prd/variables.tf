locals {
  /************************************************************
   * ★ プロジェクト設定 - 新規PJ作成時はここだけ編集する
   ************************************************************/

  project_name = "REPLACE_ME_PROJECT_NAME" // 例: "my-app"
  env          = "prd"

  account_id = "REPLACE_ME_ACCOUNT_ID"     // 例: "123456789012"
  region     = "ap-northeast-1"

  domain     = "REPLACE_ME_DOMAIN"         // 例: "example.com"
  api_domain = "api.REPLACE_ME_DOMAIN"     // 例: "api.example.com"

  // ★ backend.tf の bucket と同じ値にすること
  tfstate_bucket = "REPLACE_ME_TFSTATE_BUCKET"
  // ★ backend.tf の profile と同じ値にすること
  aws_profile = "REPLACE_ME_AWS_PROFILE"

  github_repo = "REPLACE_ME_GITHUB_REPO"   // 例: "my-org/ecs-basic"

  /************************************************************
   * 派生値（通常編集不要）
   ************************************************************/

  ssm_prefix         = "/ecspresso-${local.env}"
  public_subnet_ids  = [module.subnet.id_public_1a,  module.subnet.id_public_1c]
  private_subnet_ids = [module.subnet.id_private_1a, module.subnet.id_private_1c]
}
