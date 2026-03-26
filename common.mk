SHELL := /bin/bash -o pipefail
GIT_COMMIT_HASH ?= $(shell git rev-parse --short HEAD)

.PHONY: cp-env

cp-env:
	cp .env.sample .env

.check-env:
ifndef ENV
	$(error ENV is required.)
endif
