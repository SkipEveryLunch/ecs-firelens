AWS_MK_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
include $(AWS_MK_DIR)/common.mk

AWS_REGION ?= ap-northeast-1
AWS_ACCOUNT_ID ?= YOUR_ACCOUNT_ID

IMAGE_REPOSITORY_BASE := ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
# ECR_NAMEが指定されていない場合は、コマンド実行時のcurrent directory名をECR_NAMEとして使用する
# ※ server/ で実行すると "server" になるので、各サービスのMakefileでECR_NAMEを明示指定すること
ECR_NAME ?= $(shell basename $(CURDIR))
IMAGE_REPOSITORY_URI := ${IMAGE_REPOSITORY_BASE}/${ECR_NAME}-${ENV}
PARAMETER_STORE_NAME_IMAGE_TAG := image-tag-${ECR_NAME}-${ENV}

# ECRにログインする
# e.g. make docker-login ENV=prd
docker-login: .check-env .check-ecr-name
	aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${IMAGE_REPOSITORY_URI}

# Dockerイメージをビルドする
# e.g. make build-image ENV=prd
build-image: .check-env .check-ecr-name
	docker build --platform=linux/amd64 -t ${IMAGE_REPOSITORY_URI}:${GIT_COMMIT_HASH} -f Dockerfile .

# DockerイメージをECRにpushする
# e.g. make push-image ENV=prd
push-image: .check-env .check-ecr-name
	docker push ${IMAGE_REPOSITORY_URI}:${GIT_COMMIT_HASH}

# DockerイメージをビルドしてECRにpushする
# e.g. make release-image ENV=prd
release-image: docker-login build-image push-image

# Parameter Storeで管理しているimageタグを更新する
update-image-tag: .check-env
	aws ssm put-parameter --name ${PARAMETER_STORE_NAME_IMAGE_TAG} --value ${GIT_COMMIT_HASH} --type String --overwrite > /dev/null

# ECR URIを取得する
# e.g. make get-ecr-uri ENV=prd
get-ecr-uri: .check-env
	@echo ${IMAGE_REPOSITORY_URI}:$(shell aws ssm get-parameter --name ${PARAMETER_STORE_NAME_IMAGE_TAG} --query Parameter.Value --output text)

.PHONY: docker-login build-image push-image release-image update-image-tag get-ecr-uri

.check-ecr-name:
ifndef ECR_NAME
	$(error ECR_NAME is required.)
endif
