-include env_make

MYSQL_VER ?= 8.4.11
MYSQL_VER_MINOR = $(shell echo "$(MYSQL_VER)" | grep -oE '^[0-9]+\.[0-9]+')

TAG ?= $(MYSQL_VER_MINOR)
REPO = wodby/mysql
NAME = mysql-$(MYSQL_VER_MINOR)
PLATFORM ?= linux/arm64

ifneq ($(ARCH),)
	override TAG := $(TAG)-$(ARCH)
endif

.PHONY: build buildx-build buildx-push buildx-imagetools-create test push shell run start stop logs clean release

# Resolve the same pinned base image for every local and CI build target.
include base-images.mk
BASE_IMAGE_TAG = $(MYSQL_VER)

default: build

build:
	docker build --build-arg BASE_IMAGE="$(BASE_IMAGE)" --build-arg BUILD_IMAGE_GOSU="$(BUILD_IMAGE_GOSU)" --pull -t $(REPO):$(TAG) \
		--build-arg MYSQL_VER=$(MYSQL_VER) \
		--build-arg GOTPL_REFRESH=$$(date +%s) \
		--build-arg GOSU_REFRESH=$$(date +%s) \
		./

buildx-build:
	docker buildx build --build-arg BASE_IMAGE="$(BASE_IMAGE)" --build-arg BUILD_IMAGE_GOSU="$(BUILD_IMAGE_GOSU)" --pull --platform $(PLATFORM) --load -t $(REPO):$(TAG) \
		--build-arg MYSQL_VER=$(MYSQL_VER) \
		--build-arg GOTPL_REFRESH=$$(date +%s) \
		--build-arg GOSU_REFRESH=$$(date +%s) \
		./

buildx-push:
	docker buildx build --build-arg BASE_IMAGE="$(BASE_IMAGE)" --build-arg BUILD_IMAGE_GOSU="$(BUILD_IMAGE_GOSU)" --pull --platform $(PLATFORM) --push -t $(REPO):$(TAG) \
		--build-arg MYSQL_VER=$(MYSQL_VER) \
		--build-arg GOTPL_REFRESH=$$(date +%s) \
		--build-arg GOSU_REFRESH=$$(date +%s) \
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
