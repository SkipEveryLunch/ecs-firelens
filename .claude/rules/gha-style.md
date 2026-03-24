# GitHub Actions / Makefile Style Rules

## ワークフロー構成パターン

ecs-basicは **単一サービス**（RoRアプリ）のため、マイクロサービス向けの
`find-build-targets` による差分検出は不要。シンプルな直列構成とする:

```
setup → build → migrate → deploy
```

### setup ジョブ
ブランチ名から環境変数を解決して後続ジョブに渡す:

```yaml
- develop → env=stg, OIDC_IAM_ROLE_ARN_STG
- main    → env=prd, OIDC_IAM_ROLE_ARN_PRD
```

outputs として `env`, `oidc-iam-role-arn`, `aws-account-id` を後続ジョブに渡す。

### build ジョブ
`server/` ディレクトリで `make release-image update-image-tag` を実行:

```yaml
- name: Build and push
  working-directory: server
  run: |
    make release-image update-image-tag \
      ENV=${{ needs.setup.outputs.env }} \
      AWS_ACCOUNT_ID=${{ needs.setup.outputs.aws-account-id }}
```

### migrate ジョブ
ecspresso で `db:migrate` を単発タスクとして実行:

```yaml
- name: Run DB migration
  working-directory: ./ops/ecspresso/db-migrator/${{ needs.setup.outputs.env }}
  run: ecspresso run --watch-container app
```

### deploy ジョブ

```yaml
- name: Deploy
  working-directory: ./ops/ecspresso/api/${{ needs.setup.outputs.env }}
  run: ecspresso deploy
```

## aws.mk パターン

リポジトリルートに `aws.mk` / `common.mk` を置き、各サービスの `Makefile` から `include` する。

### common.mk
```makefile
GIT_COMMIT_HASH ?= $(shell git rev-parse --short HEAD)
```

### aws.mk の主要変数
```makefile
ECR_NAME ?= $(shell basename $(CURDIR))   # デフォルトはディレクトリ名
IMAGE_REPOSITORY_URI := ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_NAME}-${ENV}
PARAMETER_STORE_NAME_IMAGE_TAG := image-tag-${ECR_NAME}-${ENV}
```

### 主要ターゲット
| ターゲット | 処理 |
|---|---|
| `release-image` | `docker-login` → `build-image` → `push-image` |
| `build-image` | `docker build --platform=linux/amd64 -t {URI}:{GIT_COMMIT_HASH}` |
| `update-image-tag` | `aws ssm put-parameter --name image-tag-{ecr-name}-{env} --value {hash} --overwrite` |

### サービスのMakefile
`ECR_NAME` は **必ず明示指定** する（デフォルトの `basename CURDIR` に依存しない）:

```makefile
# ❌ Bad: server/ で実行すると ECR_NAME=server になる
include $(ROOT_DIR)/aws.mk

# ✅ Good: プロジェクト名を明示指定
ECR_NAME = my-app-project-name
ROOT_DIR = ../
include $(ROOT_DIR)/aws.mk
```

## SSMイメージタグの命名規則

```
image-tag-{ecr-name}-{env}
```

例: `image-tag-my-app-prd`

- CI/CDがビルド後に書き込む
- ecspressoのタスク定義で `{{ ssm \`image-tag-{ecr-name}-{env}\` }}` として参照

## OIDC認証設定

GHA→AWSの認証はOIDCで行う。`permissions` は最小権限:

```yaml
permissions:
  id-token: write   # OIDC token取得に必要
  contents: read
  actions: read     # gh api でワークフロー結果を取得する場合
```

GitHub Variables（`vars.*`）にOIDCロールARN・アカウントIDを格納し、
`secrets.*` にはSlackトークン等の機密情報のみ格納する。
