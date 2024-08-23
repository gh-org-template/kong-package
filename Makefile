ARCHITECTURE ?= x86_64
DOCKER_TARGET ?= build
DOCKER_REGISTRY ?= ghcr.io
DOCKER_IMAGE_NAME ?= kong-package
DOCKER_IMAGE_TAG ?= $(DOCKER_TARGET)-$(ARCHITECTURE)-$(OSTYPE)
DOCKER_NAME ?= $(DOCKER_REGISTRY)/$(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG)
DOCKER_RESULT ?= --load
PACKAGE_TYPE ?= deb

ifeq ($(OPERATING_SYSTEM),alpine)
	OSTYPE?=linux-musl
else
	OSTYPE?=linux-gnu
endif

ifeq ($(OPERATING_SYSTEM),rhel)
	PACKAGE_TYPE=rpm
else ifeq ($(OPERATING_SYSTEM),amazonlinux)
	PACKAGE_TYPE=rpm
else ifeq ($(OPERATING_SYSTEM),alpine)
	PACKAGE_TYPE=apk
else
	PACKAGE_TYPE=deb
endif

ifeq ($(ARCHITECTURE),aarch64)
	DOCKER_ARCHITECTURE=arm64
else
	DOCKER_ARCHITECTURE=amd64
endif

clean:
	rm -rf package
	docker rmi $(DOCKER_NAME)
	-docker kill docker kill package-validation-tests
	-docker kill systemd

docker:
	docker buildx build \
		--build-arg DOCKER_REGISTRY=$(DOCKER_REGISTRY) \
		--build-arg DOCKER_IMAGE_NAME=$(DOCKER_IMAGE_NAME) \
		--build-arg DOCKER_IMAGE_TAG=$(DOCKER_IMAGE_TAG) \
		--build-arg ARCHITECTURE=$(ARCHITECTURE) \
		--build-arg OSTYPE=$(OSTYPE) \
		--build-arg PACKAGE_TYPE=$(PACKAGE_TYPE) \
		--build-arg OPERATING_SYSTEM=$(OPERATING_SYSTEM) \
		--build-arg OPERATING_SYSTEM_VERSION=$(OPERATING_SYSTEM_VERSION) \
		--build-arg DOCKER_ARCHITECTURE=$(DOCKER_ARCHITECTURE) \
		--target=$(DOCKER_TARGET) \
		-t $(DOCKER_NAME) \
		$(DOCKER_RESULT) .

build/docker:
	docker inspect --format='{{.Config.Image}}' $(DOCKER_NAME) || \
	$(MAKE) DOCKER_TARGET=build docker

package: build/docker
	$(MAKE) DOCKER_TARGET=package DOCKER_RESULT="-o package" docker

package/test:
	PACKAGE_TYPE=$(PACKAGE_TYPE) \
	DOCKER_ARCHITECTURE=$(DOCKER_ARCHITECTURE) \
	/bin/bash ./test-package.sh

.PHONY: init
init:
	pre-commit install

.PHONY: run-pre-commit
run-pre-commit:
	pre-commit run --all-files
