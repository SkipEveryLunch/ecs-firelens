/************************************************************
 * ECSタスク実行ロール
 ************************************************************/
resource "aws_iam_role" "ecs_task_execution" {
  name = "ecs-task-execution-${var.env}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  for_each = {
    task_execution  = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
    secrets_manager = aws_iam_policy.secrets_manager_read.arn
    ssm             = aws_iam_policy.ssm_read.arn
  }
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = each.value
}

/************************************************************
 * ECSタスクロール（アプリ用）
 ************************************************************/
resource "aws_iam_role" "ecs_task" {
  name = "${var.project_name}-${var.env}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

/************************************************************
 * GitHub Actions デプロイ用ロール
 ************************************************************/
resource "aws_iam_role" "github_actions" {
  name = "github-actions-${var.project_name}-${var.env}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_github_actions_arn
        }
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  for_each = {
    ecr             = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
    ecs             = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
    parameter_store = aws_iam_policy.ssm_read_write.arn
    pass_role       = aws_iam_policy.pass_role_to_ecs_task.arn
  }
  role       = aws_iam_role.github_actions.name
  policy_arn = each.value
}

/************************************************************
 * カスタムポリシー
 ************************************************************/
resource "aws_iam_policy" "secrets_manager_read" {
  name = "secrets-manager-read-${var.env}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "ssm_read" {
  name = "ssm-read-${var.env}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "ssm_read_write" {
  name = "ssm-read-write-${var.env}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath", "ssm:PutParameter"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "pass_role_to_ecs_task" {
  name = "pass-role-to-ecs-task-${var.env}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "*"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ecs-tasks.amazonaws.com"
          }
        }
      }
    ]
  })
}
