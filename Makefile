-include env_make

MYSQL_VER ?= 8.0.46
MYSQL_VER_MINOR = $(shell echo "$(MYSQL_VER)" | grep -oE '^[0-9]+\.[0-9]+')

GOTPL_VERSION ?= 0.6.8
GOTPL_SHA256_AMD64 ?= 369b8f484b13c532dd7729ecd467accd7f57431074fe60e6ba902edec168c7ac
GOTPL_SHA256_ARM64 ?= 51ad91b90a598262f23b6ed3f48c5b3adbad0a2f3ac543db277bebe4148567fb

TAG ?= $(MYSQL_VER_MINOR)
REPO = wodby/mysql
NAME = mysql-$(MYSQL_VER_MINOR)
PLATFORM ?= linux/arm64

ifneq ($(ARCH),)
	override TAG := $(TAG)-$(ARCH)
endif

.PHONY: build buildx-build buildx-push buildx-imagetools-create test push shell run start stop logs clean release

default: build

build:
	docker build -t $(REPO):$(TAG) \
		--build-arg MYSQL_VER=$(MYSQL_VER) \
		--build-arg GOTPL_VERSION=$(GOTPL_VERSION) \
		--build-arg GOTPL_SHA256_AMD64=$(GOTPL_SHA256_AMD64) \
		--build-arg GOTPL_SHA256_ARM64=$(GOTPL_SHA256_ARM64) \
		./

buildx-build:
	docker buildx build --platform $(PLATFORM) --load -t $(REPO):$(TAG) \
		--build-arg MYSQL_VER=$(MYSQL_VER) \
		--build-arg GOTPL_VERSION=$(GOTPL_VERSION) \
		--build-arg GOTPL_SHA256_AMD64=$(GOTPL_SHA256_AMD64) \
		--build-arg GOTPL_SHA256_ARM64=$(GOTPL_SHA256_ARM64) \
		./

buildx-push:
	docker buildx build --platform $(PLATFORM) --push -t $(REPO):$(TAG) \
		--build-arg MYSQL_VER=$(MYSQL_VER) \
		--build-arg GOTPL_VERSION=$(GOTPL_VERSION) \
		--build-arg GOTPL_SHA256_AMD64=$(GOTPL_SHA256_AMD64) \
		--build-arg GOTPL_SHA256_ARM64=$(GOTPL_SHA256_ARM64) \
		./

buildx-imagetools-create:
	docker buildx imagetools create -t $(REPO):$(TAG) \
		$(REPO):$(MYSQL_VER_MINOR)-amd64 \
		$(REPO):$(MYSQL_VER_MINOR)-arm64

test:
	cd ./tests && IMAGE=$(REPO):$(TAG) NAME=$(NAME) MYSQL_VER=$(MYSQL_VER) ./run.sh

push:
	docker push $(REPO):$(TAG)

shell:
	docker run --rm --name $(NAME) -e MYSQL_ROOT_PASSWORD=password -it $(PORTS) $(VOLUMES) $(ENV) $(REPO):$(TAG) /bin/bash

run:
	docker run --rm --name $(NAME) -e MYSQL_ROOT_PASSWORD=password $(PORTS) $(VOLUMES) $(ENV) $(REPO):$(TAG) $(CMD)

start:
	docker run -d --name $(NAME) -e MYSQL_ROOT_PASSWORD=password $(PORTS) $(VOLUMES) $(ENV) $(REPO):$(TAG)

stop:
	docker stop $(NAME)

logs:
	docker logs $(NAME)

clean:
	-docker rm -f $(NAME)

release: build push

# Keep CI scans aligned with the version, variant and architecture built by make.
.PHONY: image-ref
image-ref:
	@printf '%s\n' '$(REPO):$(TAG)'
