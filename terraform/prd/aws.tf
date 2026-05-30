// Data Sources（手動作成済みリソースの参照）
data "aws_caller_identity" "current" {}

data "aws_route53_zone" "main" {
  name = local.domain
}

data "aws_acm_certificate" "main" {
  domain      = "*.${local.domain}"
  statuses    = ["ISSUED"]
  most_recent = true
}

/************************************************************
 * Network
 ************************************************************/
module "vpc" {
  source       = "../modules/aws/vpc"
  project_name = local.project_name
  env          = local.env
}

module "subnet" {
  source       = "../modules/aws/subnet"
  project_name = local.project_name
  env          = local.env
  vpc_id       = module.vpc.id
}

module "internet_gateway" {
  source       = "../modules/aws/internet_gateway"
  project_name = local.project_name
  env          = local.env
  vpc_id       = module.vpc.id
}

module "route_table" {
  source              = "../modules/aws/route_table"
  project_name        = local.project_name
  env                 = local.env
  vpc_id              = module.vpc.id
  internet_gateway_id = module.internet_gateway.id
  public_subnet_ids   = local.public_subnet_ids
  private_subnet_ids  = local.private_subnet_ids
}

/************************************************************
 * Security Groups
 ************************************************************/
module "security_group" {
  source       = "../modules/aws/security_group"
  project_name = local.project_name
  env          = local.env
  vpc_id       = module.vpc.id
}

/************************************************************
 * ECR
 ************************************************************/
module "ecr" {
  source       = "../modules/aws/ecr"
  project_name = local.project_name
  env          = local.env
}

module "ecr_log_router" {
  source       = "../modules/aws/ecr"
  project_name = local.project_name
  env          = local.env
  name         = "${local.project_name}-log-router-${local.env}"
}

/************************************************************
 * ECS
 ************************************************************/
module "ecs" {
  source       = "../modules/aws/ecs"
  project_name = local.project_name
  env          = local.env
}

/************************************************************
 * ALB
 ************************************************************/
module "target_group" {
  source       = "../modules/aws/target_group"
  project_name = local.project_name
  env          = local.env
  vpc_id       = module.vpc.id
}

module "alb" {
  source            = "../modules/aws/alb"
  project_name      = local.project_name
  env               = local.env
  security_group_id = module.security_group.id_alb
  subnet_ids        = local.public_subnet_ids
  certificate_arn   = data.aws_acm_certificate.main.arn
  target_group_arn  = module.target_group.arn
}

/************************************************************
 * RDS (PostgreSQL)
 ************************************************************/
module "rds" {
  source            = "../modules/aws/rds"
  project_name      = local.project_name
  env               = local.env
  security_group_id = module.security_group.id_rds
  subnet_ids        = local.private_subnet_ids
}

/************************************************************
 * CloudWatch Log Groups
 ************************************************************/
module "cloudwatch_log_group" {
  source       = "../modules/aws/cloudwatch_log_group"
  project_name = local.project_name
  env          = local.env
}

/************************************************************
 * IAM
 ************************************************************/
module "oidc_github_actions" {
  source = "../modules/aws/oidc_github_actions"
}

module "iam_role" {
  source                  = "../modules/aws/iam_role"
  project_name            = local.project_name
  env                     = local.env
  oidc_github_actions_arn = module.oidc_github_actions.arn
  github_repo             = local.github_repo
}

/************************************************************
 * Route53
 ************************************************************/
module "route53" {
  source  = "../modules/aws/route53"
  zone_id = data.aws_route53_zone.main.zone_id
  records = [
    {
      name = local.api_domain
      type = "A"
      alias = {
        zone_id                = module.alb.zone_id
        name                   = module.alb.dns_name
        evaluate_target_health = true
      }
    }
  ]
}

/************************************************************
 * Parameter Store（ecspresso連携用SSMパラメータ）
 * MEMO: 他モジュールへの依存が多いため最後に配置
 ************************************************************/
module "parameter_store" {
  source = "../modules/aws/parameter_store"
  parameters = {
    "${local.ssm_prefix}/aws-account-id"      = local.account_id
    "${local.ssm_prefix}/ecs-cluster-name"    = module.ecs.cluster_name
    "${local.ssm_prefix}/sg-id-ecs"           = module.security_group.id_ecs
    "${local.ssm_prefix}/tg-arn-api"          = module.target_group.arn
    "${local.ssm_prefix}/public-subnet-id-1a" = module.subnet.id_public_1a
    "${local.ssm_prefix}/public-subnet-id-1c" = module.subnet.id_public_1c
    "${local.ssm_prefix}/rds-secret-arn" = module.rds.secret_arn
    "${local.ssm_prefix}/rds-host"       = module.rds.endpoint
  }
}

# 手動登録用の箱。初回のみ REPLACE_ME を作成し、以降は値を上書きしない
resource "aws_ssm_parameter" "slack_webhook_uri" {
  name  = "${local.ssm_prefix}/slack-webhook-uri"
  type  = "String"
  value = "REPLACE_ME"
  lifecycle {
    ignore_changes = [value]
  }
}

# CI/CDがビルド後に書き込む。初回のみ REPLACE_ME を作成し、以降は値を上書きしない
resource "aws_ssm_parameter" "log_router_image_tag" {
  name  = "image-tag-${local.project_name}-log-router-${local.env}"
  type  = "String"
  value = "REPLACE_ME"
  lifecycle {
    ignore_changes = [value]
  }
}
