#!/usr/bin/env bash

set -euo pipefail

if [[ "${GITHUB_REF}" != refs/heads/main && "${GITHUB_REF}" != refs/tags/* ]]; then
    exit 0
fi

minor_ver="${MYSQL_VER%.*}"
major_ver="${minor_ver%.*}"
tags=("${minor_ver}")

if [[ -n "${LATEST_MAJOR:-}" ]]; then
    tags+=("${major_ver}")
fi

if [[ "${GITHUB_REF}" == refs/tags/* ]]; then
    image_revision="${GITHUB_REF##*/}"
    tags=("${minor_ver}-${image_revision}")
    if [[ -n "${LATEST_MAJOR:-}" ]]; then
        tags+=("${major_ver}-${image_revision}")
    fi
elif [[ -n "${LATEST:-}" ]]; then
    tags+=(latest)
fi

for tag in "${tags[@]}"; do
    make buildx-imagetools-create TAG="${tag}"
done
