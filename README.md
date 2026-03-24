# ecs-basic

ECS Fargate + ALB + Aurora Serverless v2 構成のRoRバックエンドAPIテンプレート。

## 構成

```
terraform/   インフラ (Terraform)
server/      アプリ (Ruby on Rails)
ops/         デプロイ設定 (ecspresso)
.github/     CI/CD (GitHub Actions)
```

---

## 初回セットアップ

### 1. 前提ツールのインストール

```bash
# Terraform (tenv で管理)
tenv tf install 1.11.3
tenv tf use 1.11.3

# ecspresso
brew install kayac/tap/ecspresso
```

### 2. プレースホルダーを埋める

以下2ファイルの `REPLACE_ME_*` を実際の値に書き換える。

**`terraform/prd/variables.tf`**（ここだけ編集すれば基本OK）

| プレースホルダー | 設定値 |
|---|---|
| `REPLACE_ME_PROJECT_NAME` | プロジェクト名（例: `my-app`） |
| `REPLACE_ME_ACCOUNT_ID` | AWSアカウントID |
| `REPLACE_ME_DOMAIN` | ドメイン名（例: `example.com`） |
| `REPLACE_ME_TFSTATE_BUCKET` | tfstate用S3バケット名 |
| `REPLACE_ME_AWS_PROFILE` | AWSプロファイル名 |
| `REPLACE_ME_GITHUB_REPO` | GitHubリポジトリ（例: `my-org/ecs-basic`） |

**`terraform/prd/backend.tf`**（`variables.tf` と同じ値を設定）

```hcl
bucket  = "（REPLACE_ME_TFSTATE_BUCKETと同じ値）"
profile = "（REPLACE_ME_AWS_PROFILEと同じ値）"
```

### 3. 手動でAWSリソースを作成

以下は `terraform apply` の前に手動で作成が必要なリソース（DNS伝播待ちを避けるため）:

| リソース | 手順 |
|---|---|
| **tfstate用S3バケット** | `aws s3api create-bucket --bucket {バケット名} --region ap-northeast-1 --create-bucket-configuration LocationConstraint=ap-northeast-1` |
| **Route53 Hosted Zone** | AWSコンソールまたはCLIで作成し、ドメインレジストラにNSレコードを登録 |
| **ACM証明書** | `*.{ドメイン名}` のワイルドカード証明書をap-northeast-1で発行・DNS検証を完了させる |

### 4. Terraform 初期化

```bash
cd terraform/prd
terraform init
```

### 5. 動作確認

```bash
# 構文チェック（AWS接続不要）
terraform validate

# 差分確認（AWS接続必要）
terraform plan
```

---

## インフラのデプロイ

```bash
cd terraform/prd
terraform apply
```

---

## アプリのデプロイ

初回（terraform apply後）:

```bash
# ECRリポジトリにイメージをpush
cd server
make release-image ENV=prd AWS_ACCOUNT_ID={アカウントID}
make update-image-tag ENV=prd AWS_ACCOUNT_ID={アカウントID}

# DBマイグレーション
cd ../ops/ecspresso/db-migrator/prd
ecspresso run --watch-container app

# サービスデプロイ
cd ../../api/prd
ecspresso deploy
```

2回目以降は GitHub Actions (`main` ブランチへのpush) で自動実行される。

---

## GitHub Actions の設定

リポジトリの Settings > Variables に以下を登録:

| Variable | 値 |
|---|---|
| `AWS_ACCOUNT_ID_PRD` | AWSアカウントID |
| `OIDC_IAM_ROLE_ARN_PRD` | GitHub ActionsのOIDCロールARN（terraform applyで作成される） |
