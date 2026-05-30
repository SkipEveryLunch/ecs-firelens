resource "aws_ecr_repository" "main" {
  name                 = var.name != "" ? var.name : "${var.project_name}-${var.env}"
  image_tag_mutability = "IMMUTABLE"
}

resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "最新の${var.retained_image_count}世代のみ保持"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.retained_image_count
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
