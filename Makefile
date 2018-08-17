# import config.
# You can change the default config with `make cnf="config_special.env" build`
cnf ?= config.env
-include $(cnf)
#export $(shell sed 's/=.*//' $(cnf))

# import deploy config
# You can change the default deploy config with `make cnf="deploy_special.env" release`
ROOT_DIR := $(dir $(realpath $(firstword $(MAKEFILE_LIST))))
dpl ?= $(ROOT_DIR)/deploy.env
include $(dpl)
#export $(shell sed 's/=.*//' $(dpl))

# grep the version from the mix file
VERSION=$(shell $(ROOT_DIR)/version.sh)


# HELP
# This will output the help for each task
# thanks to https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help

help: ## This help.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help


# DOCKER TASKS

# Build the container
.PHONY: build

build: ## Build the image
	@echo 'Build $(APP_NAME) image'
	docker build --build-arg tipseq_hunter_data=$(TIPSEQ_HUNTER_DATA) -t $(APP_NAME) .

.PHONY: build-nc

build-nc: ## Build the image without caching
	@echo 'Build $(APP_NAME) image no caching'
	docker build --no-cache --build-arg tipseq_hunter_data=$(TIPSEQ_HUNTER_DATA) -t $(APP_NAME) .

.PHONY: remove

remove: ## Remove the image
	@echo 'Remove $(APP_NAME) image'
	docker rmi $(APP_NAME)

# Run the container
.PHONY: run

run: run-pipeline run-pipeline-somatic ## Run TIPseqHunter pipeline completely

.PHONY: run-pipeline

run-pipeline: check-env ## Run TIPseqHunterPipelineJar.sh
	@echo 'TIPseqHunterPipelineJar.sh $(INPUT_DIR) $(OUTPUT_DIR) $(FASTQ_R1) $(KEY_R1) $(KEY_R2) $(READ_NUM)'
	docker run \
		--rm \
		-u $(shell id -u):$(shell id -g) \
		--env-file=$(cnf) \
		--name=$(CONTAINER_NAME) \
		-v /etc/passwd:/etc/passwd:ro \
		-v /etc/group:/etc/group:ro \
		-v $(strip $(INPUT_DIR)):$(strip $(INPUT_DIR)) \
		-v $(strip $(OUTPUT_DIR)):$(strip $(OUTPUT_DIR)) \
		-w $(OUTPUT_DIR) \
		$(APP_NAME) TIPseqHunterPipelineJar.sh >&2

.PHONY: run-pipeline-somatic

run-pipeline-somatic: check-args ## Run TIPseqHunterPipelineJarSomatic.sh
	docker run --rm --env-file=$(cnf) --name=$(APP_NAME) $(APP_NAME)

.PHONY: up

up: build run ## Run TIPseqHunter pipeline completely (Alias to run)

.PHONY: check-env

check-env: ## Check if INPUT_DIR/OUTPUT_DIR `args` are defined
ifndef INPUT_DIR
	$(error 'INPUT_DIR' is not defined)
endif
ifndef OUTPUT_DIR
	$(error 'OUTPUT_DIR' is not defined)
endif

.PHONY: stop

stop: ## Stop and remove a running container
	docker stop $(CONTAINER_NAME); docker rm $(CONTAINER_NAME)

.PHONY: release

release: build publish ## Make a release by building and publishing the `{version}` ans `latest` tagged containers to dockerhub

# Docker publish
.PHONY: publish

publish: repo-login publish-latest publish-version repo-logout ## Publish the `{version}` ans `latest` tagged containers to dockerhub

.PHONY: publish-latest

publish-latest: tag-latest ## Publish the `latest` taged container to dockerhub
	@echo 'publish latest to $(DOCKER_REPO)'
	docker push $(DOCKER_REPO)/$(APP_NAME):latest

.PHONY: publish-version

publish-version: tag-version ## Publish the `{version}` taged container to dockerhub
	@echo 'publish $(VERSION) to $(DOCKER_REPO)'
	docker push $(DOCKER_REPO)/$(APP_NAME):$(VERSION)

# Docker tagging
.PHONY: tag

tag: tag-latest tag-version ## Generate container tags for the `{version}` ans `latest` tags

.PHONY: tag-latest

tag-latest: ## Generate container `{version}` tag
	@echo 'create tag latest'
	docker tag $(APP_NAME) $(DOCKER_REPO)/$(APP_NAME):latest

.PHONY: tag-version

tag-version: ## Generate container `latest` tag
	@echo 'create tag $(VERSION)'
	docker tag $(APP_NAME) $(DOCKER_REPO)/$(APP_NAME):$(VERSION)

# HELPERS

# login to dockerhub
.PHONY: repo-login

repo-login: ## Login to dockerhub registry
	@echo 'login to dockerhub registry'
	docker login -u $(USER_NAME)

repo-logout: ## Logout from dockerhub registry
	@echo 'logout from dockerhub registry'
	docker logout

.PHONY: version

version: ## Output the current version
	@echo $(VERSION)

