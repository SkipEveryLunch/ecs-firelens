# ecspresso Style Rules

## ファイル構成

`ops/ecspresso/` 配下に用途別ディレクトリを置き、環境ごとに3ファイルを管理する。
api / db-migrator / worker でDockerイメージは共有するが、タスク定義・サービス定義が異なるためディレクトリは分ける:

```
ops/ecspresso/
├── api/
│   └── prd/
│       ├── ecspresso.yml
│       ├── ecs-task-def.json
│       └── ecs-service-def.json
└── db-migrator/
    └── prd/
        ├── ecspresso.yml
        ├── ecs-task-def.json
        └── ecs-service-def.json
```

## ecspresso.yml

```yaml
region: ap-northeast-1
cluster: "{{ ssm `/ecspresso-prd/ecs-cluster-name` }}"
service: my-app-api-prd    # 常駐サービス。単発タスクは service: ""
service_definition: ecs-service-def.json
task_definition: ecs-task-def.json
timeout: "10m0s"
```

## SSMパラメータの参照パターン

ecspressoのJSONでは2種類の参照方法を使い分ける:

```json
// ① Terraformが /ecspresso-{env}/ に保存した値（インフラID/ARN）
"{{ ssm `/ecspresso-prd/sg-id-ecs` }}"
"{{ ssm `/ecspresso-prd/tg-arn-api` }}"
"{{ ssm `/ecspresso-prd/aws-account-id` }}"

// ② SecretsManagerのシークレット名からARNを逆引き（DB認証情報）
"{{ secretsmanager_arn `my-secret-name`}}:field::"
```

Aurora の `manage_master_user_password = true` を使う場合はシークレット名が
固定されないため、TerraformがSSMに `rds-secret-arn` を保存して ① で参照する。

## ecs-task-def.json

### 全体構造
```json
{
  "family": "{project_name}-api-prd",
  "cpu": "256",
  "memory": "512",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "executionRoleArn": "arn:aws:iam::{{ ssm `/ecspresso-prd/aws-account-id` }}:role/ecs-task-execution-prd",
  "taskRoleArn": "arn:aws:iam::{{ ssm `/ecspresso-prd/aws-account-id` }}:role/{project_name}-prd",
  "containerDefinitions": [ ... ],
  "tags": [{"key": "Env", "value": "prd"}]
}
```

### containerDefinitions のルール
- `"cpu": 0` — コンテナレベルのCPUは0（タスクレベルで制御）
- `"readonlyRootFilesystem": true` — 原則true（stg環境はfalseにしてデバッグ容易に）
- `"essential": true` — 常に指定
- ログ設定に `"awslogs-create-group": "true"` を必ず含める
- `ipcMode: ""`, `pidMode: ""` は空文字で明示しない（省略可）

```json
{
  "name": "app",
  "image": "{{ ssm `/ecspresso-prd/aws-account-id` }}.dkr.ecr.ap-northeast-1.amazonaws.com/{project_name}-prd:{{ ssm `image-tag-{project_name}-prd` }}",
  "cpu": 0,
  "essential": true,
  "portMappings": [{"containerPort": 3000, "protocol": "tcp"}],
  "healthCheck": {
    "command": ["CMD-SHELL", "curl -f http://localhost:3000/health || exit 1"],
    "interval": 30,
    "timeout": 5,
    "retries": 3,
    "startPeriod": 0
  },
  "secrets": [
    {"name": "DB_HOST",     "valueFrom": "{{ ssm `/ecspresso-prd/rds-host` }}"},
    {"name": "DB_PASSWORD", "valueFrom": "{{ ssm `/ecspresso-prd/rds-secret-arn` }}:password::"},
    {"name": "DB_USERNAME", "valueFrom": "{{ ssm `/ecspresso-prd/rds-secret-arn` }}:username::"}
  ],
  "logConfiguration": {
    "logDriver": "awslogs",
    "options": {
      "awslogs-create-group": "true",
      "awslogs-group": "/ecs/{project_name}-api-prd",
      "awslogs-region": "ap-northeast-1",
      "awslogs-stream-prefix": "ecs"
    }
  },
  "readonlyRootFilesystem": true
}
```

## ecs-service-def.json

### 常駐サービス（ALBあり）
```json
{
  "desiredCount": 1,
  "capacityProviderStrategy": [
    {"capacityProvider": "FARGATE_SPOT", "weight": 1, "base": 0}
  ],
  "deploymentConfiguration": {
    "deploymentCircuitBreaker": {"enable": true, "rollback": true},
    "maximumPercent": 200,
    "minimumHealthyPercent": 100
  },
  "deploymentController": {"type": "ECS"},
  "availabilityZoneRebalancing": "DISABLED",
  "enableECSManagedTags": true,
  "enableExecuteCommand": false,
  "platformFamily": "Linux",
  "platformVersion": "1.4.0",
  "propagateTags": "NONE",
  "schedulingStrategy": "REPLICA",
  "loadBalancers": [
    {
      "containerName": "app",
      "containerPort": 3000,
      "targetGroupArn": "{{ ssm `/ecspresso-prd/tg-arn-api` }}"
    }
  ],
  "networkConfiguration": {
    "awsvpcConfiguration": {
      "assignPublicIp": "ENABLED",
      "securityGroups": ["{{ ssm `/ecspresso-prd/sg-id-ecs` }}"],
      "subnets": [
        "{{ ssm `/ecspresso-prd/public-subnet-id-1a` }}",
        "{{ ssm `/ecspresso-prd/public-subnet-id-1c` }}"
      ]
    }
  },
  "tags": [{"key": "Env", "value": "prd"}]
}
```

### 単発タスク（db-migrator等）
- `desiredCount`, `loadBalancers`, `schedulingStrategy` は不要
- 必要最小限の `capacityProviderStrategy` + `networkConfiguration` のみ

### stg環境との差分
| 項目 | prd | stg |
|---|---|---|
| `enableExecuteCommand` | false | true |
| `platformVersion` | "1.4.0" | "LATEST" |
| `readonlyRootFilesystem` | true | false |
