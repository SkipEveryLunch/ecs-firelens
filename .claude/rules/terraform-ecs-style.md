# Terraform Style Rules (ecs-basic固有)

親ディレクトリの `terraform-style.md` を前提として、ecs-basicで追加されるパターンを定義する。

## ECS モジュール（クラスターのみ）

ecspressoと分業するため、Terraformは **クラスターのみ** 管理する。
`aws_ecs_service` / `aws_ecs_task_definition` はecspresso管理のため作成しない。

```hcl
// ✅ Terraform管理: クラスターとキャパシティプロバイダーのみ
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-${var.env}"
  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
}

// ❌ ecspresso管理のためTerraformに書かない
// resource "aws_ecs_service" { ... }
// resource "aws_ecs_task_definition" { ... }
```

outputs は `cluster_arn` と `cluster_name` の両方を出力する
（`cluster_name` はparameter_storeモジュールに渡すため必要）:

```hcl
output "cluster_arn"  { value = aws_ecs_cluster.main.arn }
output "cluster_name" { value = aws_ecs_cluster.main.name }
```

## parameter_store モジュール（ecspresso連携）

Terraform → ecspresso の値渡しはSSMパラメータ経由で行う。
`map(string)` を `for_each` で一括作成するシンプルな実装:

```hcl
// modules/aws/parameter_store/main.tf
variable "parameters" {
  type = map(string)
}

resource "aws_ssm_parameter" "main" {
  for_each = var.parameters
  name     = each.key
  type     = "String"
  value    = each.value
}
```

### パラメータ命名規則

```
/ecspresso-{env}/{key}
```

| パラメータ名 | 値のソース |
|---|---|
| `/ecspresso-{env}/aws-account-id` | `local.account_id` |
| `/ecspresso-{env}/ecs-cluster-name` | `module.ecs.cluster_name` |
| `/ecspresso-{env}/sg-id-ecs` | `module.security_group.id_ecs` |
| `/ecspresso-{env}/tg-arn-api` | `module.target_group.arn` |
| `/ecspresso-{env}/public-subnet-id-1a` | `module.subnet.id_public_1a` |
| `/ecspresso-{env}/public-subnet-id-1c` | `module.subnet.id_public_1c` |
| `/ecspresso-{env}/rds-secret-arn` | `module.rds.secret_arn` |
| `/ecspresso-{env}/rds-host` | `module.rds.cluster_endpoint` |

`aws.tf` での呼び出しは他モジュールへの依存が多いため **最後に配置**:

```hcl
module "parameter_store" {
  source = "../modules/aws/parameter_store"
  parameters = {
    "${local.ssm_prefix}/aws-account-id"      = local.account_id
    "${local.ssm_prefix}/ecs-cluster-name"    = module.ecs.cluster_name
    "${local.ssm_prefix}/sg-id-ecs"           = module.security_group.id_ecs
    // ...
  }
}
```

`local.ssm_prefix = "/ecspresso-${local.env}"` を `variables.tf` に定義して使い回す。

## RDS Aurora Serverless v2

```hcl
resource "aws_rds_cluster" "main" {
  engine       = "aurora-postgresql"
  engine_mode  = "provisioned"    // ❗ Serverless v2 は "serverless" ではなく "provisioned"
  engine_version = "16.4"

  serverlessv2_scaling_configuration {
    min_capacity = var.rds.min_capacity   // 例: 0.5
    max_capacity = var.rds.max_capacity   // 例: 4.0
  }

  manage_master_user_password = true  // SecretsManagerで自動生成・ローテーション
}

resource "aws_rds_cluster_instance" "main" {
  instance_class = "db.serverless"    // Serverless v2専用のインスタンスクラス
  engine         = aws_rds_cluster.main.engine
  engine_version = aws_rds_cluster.main.engine_version
}
```

outputs で `secret_arn` を出力して `iam_role` / `parameter_store` モジュールに渡す:

```hcl
output "secret_arn" {
  value = aws_rds_cluster.main.master_user_secret[0].secret_arn
}
```

## ALB モジュール

otehonの実装と異なりHTTP→HTTPSリダイレクトを追加する（port 80リスナー）。
ゾーンIDは東京リージョン固定値をハードコードして output する:

```hcl
output "zone_id" {
  value = "Z14GRHDCWA56QT"   // 東京リージョンのALBゾーンID（固定）
}
```

## IAMロール命名規則

| ロール | 命名パターン | 例 |
|---|---|---|
| ECSタスク実行ロール | `ecs-task-execution-{env}` | `ecs-task-execution-prd` |
| ECSタスクロール | `{project_name}-{env}` | `my-app-prd` |
| GitHub Actionsロール | `github-actions-{project_name}-{env}` | `github-actions-my-app-prd` |

## variables.tf プレースホルダーパターン

テンプレートとして使い回すため、環境固有の値は全て `locals` に集約し
`REPLACE_ME_*` プレースホルダーで明示する:

```hcl
locals {
  /************************************************************
   * ★ プロジェクト設定 - 新規PJ作成時はここだけ編集する
   ************************************************************/
  project_name   = "REPLACE_ME_PROJECT_NAME"
  account_id     = "REPLACE_ME_ACCOUNT_ID"
  domain         = "REPLACE_ME_DOMAIN"
  github_repo    = "REPLACE_ME_GITHUB_REPO"
  tfstate_bucket = "REPLACE_ME_TFSTATE_BUCKET"
  aws_profile    = "REPLACE_ME_AWS_PROFILE"

  /************************************************************
   * 派生値（通常編集不要）
   ************************************************************/
  ssm_prefix         = "/ecspresso-${local.env}"
  public_subnet_ids  = [module.subnet.id_public_1a,  module.subnet.id_public_1c]
  private_subnet_ids = [module.subnet.id_private_1a, module.subnet.id_private_1c]
}
```

`backend.tf` はTerraform変数を参照できないため `variables.tf` と二重管理になる。
コメントで紐付けを明示して対処する:

```hcl
// ★ bucket/profile は variables.tf の tfstate_bucket/aws_profile と同じ値にすること
terraform {
  backend "s3" {
    bucket  = "REPLACE_ME_TFSTATE_BUCKET"
    profile = "REPLACE_ME_AWS_PROFILE"
    ...
  }
}
```
