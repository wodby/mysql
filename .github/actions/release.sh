#!/usr/bin/env bash

# Version aliases identify published releases; only primary tags publish images.
if [[ "${GITHUB_REF:-}" =~ ^refs/tags/.+-r[0-9]+$ ]]; then
    exit 0
fi

set -euo pipefail

if [[ "${GITHUB_REF}" != refs/heads/main && "${GITHUB_REF}" != refs/tags/* ]]; then
    exit 0
fi

# Take X.Y and X from the front: upstream versions may have three or four
# parts (8.4.13 or the package rebuild 8.4.13.1).
minor_ver="$(echo "${MYSQL_VER}" | grep -oE '^[0-9]+\.[0-9]+')"
major_ver="${minor_ver%%.*}"
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
