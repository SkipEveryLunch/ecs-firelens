// Data Sources（手動作成済みリソースの参照）
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
