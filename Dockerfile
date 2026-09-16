ARG MYSQL_VER=8.0.44

# Rebuild the upstream gosu source with a patched Go standard library.
FROM --platform=$BUILDPLATFORM golang:1.26.8-alpine3.23 AS gosu-build

ARG TARGETOS
ARG TARGETARCH
ARG GOSU_COMMIT=6456aaa0f3c854d199d0f037f068eb97515b7513

RUN set -eux; \
    apk add --no-cache git; \
    git init /src; \
    git -C /src fetch --depth 1 https://github.com/tianon/gosu.git "${GOSU_COMMIT}"; \
    git -C /src checkout FETCH_HEAD; \
    test "$(git -C /src rev-parse HEAD)" = "${GOSU_COMMIT}"

WORKDIR /src
RUN set -eux; \
    go mod download; \
    go mod verify; \
    CGO_ENABLED=0 GOOS="${TARGETOS:-linux}" GOARCH="${TARGETARCH}" \
        go build -trimpath -o /out/gosu .

FROM mysql:${MYSQL_VER}

ARG MYSQL_VER
ARG TARGETARCH

ENV MYSQL_VER="${MYSQL_VER}" \
    WODBY_MYSQL_CONFIG_FILE=/etc/mysql/conf.d/zz-wodby.cnf

# The upstream entrypoint starts as root to prepare the data volume and then
# drops privileges to the mysql user before starting mysqld.
# hadolint ignore=DL3002,DL3066
USER root

# The Oracle Linux repositories follow the pinned upstream base image. Exact
# package-release pins would prevent rebuilding after routine repository updates.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# hadolint ignore=DL3041
RUN set -eux; \
    microdnf remove -y mysql-shell; \
    rm -rf /usr/lib/mysqlsh; \
    # Upgrade OS packages while retaining the MySQL version selected by the base image.
    microdnf --disablerepo='mysql*' upgrade -y; \
    microdnf install -y make unzip; \
    microdnf clean all; \
    rm /usr/local/bin/gosu; \
    mkdir -p /wodby/import

# Refresh the latest release on each Make build without rebuilding OS packages.
ARG GOTPL_REFRESH=manual
RUN set -eux; \
    echo "Refreshing gotpl: ${GOTPL_REFRESH}"; \
    arch="${TARGETARCH:-}"; \
    if [ -z "${arch}" ]; then \
        case "$(uname -m)" in \
            x86_64) arch=amd64 ;; \
            aarch64) arch=arm64 ;; \
            *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;; \
        esac; \
    fi; \
    case "${arch}" in \
        amd64|arm64) ;; \
        *) echo "Unsupported architecture: ${arch}" >&2; exit 1 ;; \
    esac; \
    gotpl_archive=/tmp/gotpl.tar.gz; \
    curl --fail --location --silent --show-error \
        "https://github.com/wodby/gotpl/releases/latest/download/gotpl-linux-${arch}.tar.gz" \
        --output "${gotpl_archive}"; \
    tar --extract --gzip --file "${gotpl_archive}" --directory /usr/local/bin; \
    rm "${gotpl_archive}"

# The earlier removal records a whiteout for the inherited vulnerable binary.
COPY --from=gosu-build /out/gosu /usr/local/bin/gosu

COPY templates /etc/gotpl/
COPY bin /usr/local/bin/
COPY initdb.d /docker-entrypoint-initdb.d/
COPY docker-entrypoint.sh /wodby-entrypoint.sh

RUN chmod 0755 \
        /wodby-entrypoint.sh \
        /usr/local/bin/backup \
        /usr/local/bin/backup_stream \
        /usr/local/bin/get_archive \
        /usr/local/bin/import \
        /usr/local/bin/mysql-check \
        /usr/local/bin/mysql-dump \
        /usr/local/bin/mysql-manage \
        /usr/local/bin/wait_for_mysql; \
    chmod 0644 \
        /usr/local/bin/actions.mk \
        /usr/local/bin/mysql-common \
        /docker-entrypoint-initdb.d/00-wodby-import.sh

ENTRYPOINT ["/wodby-entrypoint.sh"]
CMD ["mysqld"]
