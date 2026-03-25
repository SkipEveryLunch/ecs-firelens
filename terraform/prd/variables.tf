locals {
  /************************************************************
   * ★ プロジェクト設定 - 新規PJ作成時はここだけ編集する
   ************************************************************/

  project_name = "ecs-basic"
  env          = "prd"

  account_id = data.aws_caller_identity.current.account_id
  region     = "ap-northeast-1"

  domain     = "skip-every-lunch-pg.click"
  api_domain = "api.skip-every-lunch-pg.click"

  // ★ backend.tf の bucket と同じ値にすること
  tfstate_bucket = "REPLACE_ME_TFSTATE_BUCKET"
  // ★ backend.tf の profile と同じ値にすること
  aws_profile = "playground"

  github_repo = "SkipEveryLunch/ecs-basic"

  /************************************************************
   * 派生値（通常編集不要）
   ************************************************************/

  ssm_prefix         = "/ecspresso-${local.env}"
  public_subnet_ids  = [module.subnet.id_public_1a,  module.subnet.id_public_1c]
  private_subnet_ids = [module.subnet.id_private_1a, module.subnet.id_private_1c]
}
