# Base image inputs shared by local builds and CI. Updated by wodby/images.
# Each digest identifies the complete multi-platform image index.
BASE_IMAGE_REPOSITORY := mysql
BASE_IMAGE_VERSION_SUFFIX :=

BASE_IMAGE_DIGEST_8.4.13 := sha256:76f0358884cb92d9a086d24e5671c38048d3fef40f2588703d73eb55392d6b69

# Build gosu from the same pinned Go image on both target architectures.
BUILD_IMAGE_GOSU := golang:alpine@sha256:d200d2dd76b03a99b52651fd1325aff7dcd35422c35c01bac56571b0507f3deb

# Fail before building when a version or variant has no reviewed pin.
BASE_IMAGE = $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG)@$(or $(BASE_IMAGE_DIGEST_$(BASE_IMAGE_TAG)),$(error No base image digest for $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG); update base-images.mk))
