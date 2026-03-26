# 自動デプロイの仕組み

## 全体像

```
┌─────────────────────────────────────────────────────────────────┐
│ ローカル                                                          │
│   git push → GitHub                                             │
└─────────────────────────────────────────────────────────────────┘
                        │
                        │ push イベント (main → prd)
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│ GitHub Actions                                                   │
│                                                                  │
│  [1] build   Docker イメージをビルドして ECR に push             │
│      │       ↓                                                   │
│      │       SSM に「最新のイメージタグ」を書き込む              │
│      ▼                                                           │
│  [2] migrate ecspresso で db:migrate タスクを単発実行            │
│      ▼                                                           │
│  [3] deploy  ecspresso で ECS サービスを更新                     │
└─────────────────────────────────────────────────────────────────┘
                        │ OIDC 認証（後述）
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│ AWS                                                              │
│                                                                  │
│   ECR          イメージの保管場所                                │
│   SSM          設定値・イメージタグの保管場所                    │
│   ECS Fargate  コンテナを実際に動かす場所                        │
│   RDS Aurora   データベース                                      │
└─────────────────────────────────────────────────────────────────┘
```

---

## 各ステップの詳細

### [1] build — イメージを作って ECR に届ける

`server/Makefile` の `make release-image update-image-tag` を実行します。
内部では以下が順番に動きます：

```
docker-login     ECR にログイン
    ↓
build-image      Dockerfile をビルド (linux/amd64)
    ↓
push-image       ECR にプッシュ
    ↓
update-image-tag SSM パラメータ "image-tag-ecs-basic-prd" に
                 git のコミットハッシュを書き込む
```

イメージのタグには `git rev-parse --short HEAD` の値（例: `a1b2c3d`）を使います。
これにより「どのコミットのコードが動いているか」が常に追跡できます。

**SSM へのイメージタグ書き込みがポイントです。**
ecspresso はこの値を参照してデプロイするイメージを決めます（後述）。

---

### [2] migrate — DB マイグレーションを先に済ませる

ecspresso の `run` コマンドで `rails db:migrate` を単発タスクとして ECS 上で実行します。

```
ecspresso run --watch-container app
```

- 新しいコンテナイメージを使ってマイグレーションを走らせる
- タスクの終了を待機し、失敗したらワークフローも止まる
- マイグレーションが成功してから deploy に進むことで、スキーマ不整合を防ぐ

---

### [3] deploy — ECS サービスを新しいイメージで更新する

ecspresso の `deploy` コマンドで ECS サービスを更新します。

```
ecspresso deploy
```

内部では以下が起きます：

```
ecs-task-def.json を読み込む（SSM 参照を解決）
    ↓
ECS に新しいタスク定義を登録する
    ↓
ECS サービスを新しいタスク定義で更新する
    ↓
ヘルスチェックが通るまで待機
    ↓
古いタスクを停止する（ローリングアップデート）
```

`deploymentCircuitBreaker` が有効なので、ヘルスチェックが失敗すると
ECS が自動的に以前のバージョンにロールバックします。

---

## SSM パラメータが「のりしろ」になっている

Terraform・GHA・ecspresso の 3 者は直接連携していません。
**SSM パラメータストアが接着剤の役割を担っています。**

```
Terraform が書き込む値（インフラの情報）
┌─────────────────────────────────────────────┐
│ /ecspresso-prd/ecs-cluster-name  クラスター名 │
│ /ecspresso-prd/tg-arn-api        ALB ターゲットグループの ARN │
│ /ecspresso-prd/sg-id-ecs         セキュリティグループ ID │
│ /ecspresso-prd/public-subnet-id-1a  サブネット ID │
│ /ecspresso-prd/rds-host          RDS のエンドポイント │
│ /ecspresso-prd/rds-secret-arn    DB 認証情報の ARN │
│ /ecspresso-prd/aws-account-id    AWS アカウント ID │
└─────────────────────────────────────────────┘

GHA (build ジョブ) が書き込む値（アプリの情報）
┌─────────────────────────────────────────────┐
│ image-tag-ecs-basic-prd          最新のイメージタグ │
└─────────────────────────────────────────────┘

ecspresso がデプロイ時に参照する
┌─────────────────────────────────────────────┐
│ ecs-task-def.json 内の {{ ssm `...` }} を    │
│ デプロイ実行時にすべて解決してから ECS に登録  │
└─────────────────────────────────────────────┘
```

この設計のメリットは、**インフラ側（Terraform）とアプリ側（ecspresso/GHA）が
お互いのコードを直接参照しなくて済む**ことです。
Terraform でリソースを作り直しても SSM の値を更新するだけで、
ecspresso のファイルを一切触らずに済みます。

---

## OIDC — AWS の認証情報をコードに書かない仕組み

GHA から AWS を操作するとき、昔は `AWS_ACCESS_KEY_ID` などの
シークレットを GitHub に登録していました。
しかしキーが漏洩するリスクがあり、ローテーションも手間でした。

OIDC を使うと、**GitHub Actions が一時的なトークンを発行し、
AWS が「このトークンは本物の GitHub Actions からのリクエストだ」と
検証する**ことで、長期的な認証情報なしに AWS を操作できます。

```
GitHub Actions
    │
    │ 「自分は github.com/SkipEveryLunch/ecs-basic の
    │   main ブランチのワークフローです」というトークンを発行
    ▼
AWS STS（認証サービス）
    │
    │ トークンを検証し、許可された IAM ロールを一時的に引き受ける
    ▼
一時的な AWS 認証情報（有効期限つき）
```

Terraform の `oidc_github_actions` モジュールが
「このリポジトリからのリクエストを信頼する」という IAM ロールを作成しています。

---

## Terraform と ecspresso の分業

| 担当 | Terraform | ecspresso |
|---|---|---|
| **管理するもの** | インフラ（VPC・ALB・RDS・ECS クラスター等） | ECS タスク定義・サービス定義 |
| **更新タイミング** | インフラ変更時（手動） | コードを push するたびに自動 |
| **状態管理** | tfstate（S3） | ECS サービスの現在の状態 |

ECS の**クラスター**は Terraform が作りますが、
**タスク定義・サービス**は ecspresso が管理します。
これにより、デプロイのたびに Terraform を実行する必要がなく、
GHA から軽量に更新できます。

---

## まとめ：一度の git push で何が起きるか

```
git push origin main
    │
    ├─ [build]   → イメージビルド → ECR push → SSM にタグ書き込み
    │
    ├─ [migrate] → ECS 上で rails db:migrate を実行・完了を待機
    │
    └─ [deploy]  → ECS サービスをローリングアップデート
                   失敗したら ECS が自動ロールバック
```

## GitHub Variables の設定

GHA を動かすにはリポジトリの Variables に以下を設定してください：

| 変数名 | 値 |
|---|---|
| `AWS_ACCOUNT_ID` | AWS アカウント ID（12 桁） |
| `OIDC_IAM_ROLE_ARN` | `arn:aws:iam::{account_id}:role/github-actions-ecs-basic-prd` |
