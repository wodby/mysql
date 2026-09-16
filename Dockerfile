ARG MYSQL_VER=8.0.44

FROM mysql:${MYSQL_VER}

ARG MYSQL_VER
ARG TARGETARCH
ARG GOTPL_VERSION=0.6.8
ARG GOTPL_SHA256_AMD64=369b8f484b13c532dd7729ecd467accd7f57431074fe60e6ba902edec168c7ac
ARG GOTPL_SHA256_ARM64=51ad91b90a598262f23b6ed3f48c5b3adbad0a2f3ac543db277bebe4148567fb

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
    # Upgrade OS packages while retaining the MySQL version selected by the base image.
    microdnf --disablerepo='mysql*' upgrade -y; \
    microdnf install -y make unzip; \
    microdnf clean all; \
    arch="${TARGETARCH:-}"; \
    if [ -z "${arch}" ]; then \
        case "$(uname -m)" in \
            x86_64) arch=amd64 ;; \
            aarch64) arch=arm64 ;; \
            *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;; \
        esac; \
    fi; \
    case "${arch}" in \
        amd64) gotpl_sha256="${GOTPL_SHA256_AMD64}" ;; \
        arm64) gotpl_sha256="${GOTPL_SHA256_ARM64}" ;; \
        *) echo "Unsupported architecture: ${arch}" >&2; exit 1 ;; \
    esac; \
    gotpl_archive=/tmp/gotpl.tar.gz; \
    curl --fail --location --silent --show-error \
        "https://github.com/wodby/gotpl/releases/download/${GOTPL_VERSION}/gotpl-linux-${arch}.tar.gz" \
        --output "${gotpl_archive}"; \
    echo "${gotpl_sha256}  ${gotpl_archive}" | sha256sum --check -; \
    tar --extract --gzip --file "${gotpl_archive}" --directory /usr/local/bin; \
    rm "${gotpl_archive}"; \
    mkdir -p /wodby/import

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
