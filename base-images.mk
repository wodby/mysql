# Base image inputs shared by local builds and CI. Updated by wodby/images.
# Each digest identifies the complete multi-platform image index.
BASE_IMAGE_REPOSITORY := mysql
BASE_IMAGE_VERSION_SUFFIX :=

BASE_IMAGE_DIGEST_8.4.11 := sha256:24989179f58856db763f418010c1169fecc944e3ec1ea7e921572d83eb070f70

# Build gosu from the same pinned Go image on both target architectures.
BUILD_IMAGE_GOSU := golang:alpine@sha256:f92b6ef800e499660581efdabdf25d9d817a9d124eaf900924f0504e7e27e12d

# Fail before building when a version or variant has no reviewed pin.
BASE_IMAGE = $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG)@$(or $(BASE_IMAGE_DIGEST_$(BASE_IMAGE_TAG)),$(error No base image digest for $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG); update base-images.mk))
