# MySQL Docker Container Image

[![Build Status](https://github.com/wodby/mysql/actions/workflows/workflow.yml/badge.svg)](https://github.com/wodby/mysql/actions/workflows/workflow.yml)
[![Docker Pulls](https://img.shields.io/docker/pulls/wodby/mysql.svg)](https://hub.docker.com/r/wodby/mysql)

MySQL 8.4 LTS Community Server with Wodby configuration and database operations.

## Image revisions

Use image revision tags such as `wodby/mysql:8.4-rN` to select a Wodby image revision.
Major and minor tags use the repository release number, starting at `r0`. Full-version tags such as
`wodby/mysql:8.4.11-r0` start at `r0` for each exact upstream version.
Every published versioned revision tag has a matching annotated Git tag pointing to its release commit.
Existing tags remain available after support for their major or minor version ends.
See [release tags](https://github.com/wodby/mysql/tags) for available revisions and the [image revision policy](https://github.com/wodby/images#image-revisions) for upgrade guidance.
Previously published image tags remain available.

## Docker images

The image extends the Docker Official Image for MySQL instead of rebuilding the
server. The upstream patch version is pinned in the Dockerfile and Makefile;
Wodby's image updater detects both new patches and rebuilt upstream tags.

Images are built for `linux/amd64` and `linux/arm64`.

| Tag | Description |
| --- | --- |
| `8.4` | Latest Wodby build of the supported MySQL 8.4 LTS patch release |
| `8` | Latest Wodby MySQL 8 build |
| `latest` | Latest supported Wodby MySQL build |
| `8.4-rN` | Immutable Wodby image revision |
| `8-rN` | Major-version alias for the same image revision |

Use image revision tags for production deployments.

Only MySQL 8.4 is built and maintained. The floating `8` and `latest` aliases now
select 8.4. Before upgrading an existing 8.0 data volume, back it up and follow
the [MySQL 8.4 upgrade requirements](https://dev.mysql.com/doc/refman/8.4/en/upgrade-prerequisites.html).

## Configuration

The upstream MySQL entrypoint remains responsible for initializing and starting
the database. Before it runs, the Wodby entrypoint renders
`/etc/mysql/conf.d/zz-wodby.cnf` from environment variables.

| Variable | Default |
| --- | --- |
| `MYSQL_BIND_ADDRESS` | `0.0.0.0` |
| `MYSQL_CHARACTER_SET_SERVER` | `utf8mb4` |
| `MYSQL_COLLATION_SERVER` | `utf8mb4_0900_ai_ci` |
| `MYSQL_CLIENT_DEFAULT_CHARACTER_SET` | `utf8mb4` |
| `MYSQL_CONNECT_TIMEOUT` | `10` |
| `MYSQL_INNODB_BUFFER_POOL_SIZE` | `128M` |
| `MYSQL_INNODB_FLUSH_LOG_AT_TRX_COMMIT` | `1` |
| `MYSQL_INTERACTIVE_TIMEOUT` | `420` |
| `MYSQL_MAX_ALLOWED_PACKET` | `256M` |
| `MYSQL_MAX_CONNECTIONS` | `100` |
| `MYSQL_NET_READ_TIMEOUT` | `90` |
| `MYSQL_NET_WRITE_TIMEOUT` | `90` |
| `MYSQL_TRANSACTION_ISOLATION` | `REPEATABLE-READ` |
| `MYSQL_WAIT_TIMEOUT` | `420` |

The standard upstream initialization variables remain available, including
`MYSQL_ROOT_PASSWORD`, `MYSQL_ROOT_HOST`, `MYSQL_DATABASE`, `MYSQL_USER`, and
`MYSQL_PASSWORD`.

## Initialization imports

Mount one SQL file or archive at `/wodby/import` when initializing a new data
volume. Supported inputs are `.sql`, `.mysql`, `.gz`, `.tar.gz`, `.tgz`, and
`.zip`. An archive must contain exactly one `.sql` or `.mysql` file.

## Orchestration actions

Run image operations through `make`:

```text
make check-ready [root_password host max_try wait_seconds delay_seconds]
make check-live [root_password host]
make query query="SELECT 1" [db user password host]
make query-silent query="SELECT 1" [db user password host]
make query-root query="SELECT 1" [db root_password host]
make create-db name charset collation [root_password host]
make drop-db name [root_password host]
make create-user username password [root_password host]
make drop-user username [root_password host]
make grant-user-db username db [root_password host]
make revoke-user-db username db [root_password host]
make mysql-check [db root_password host]
make import source [db user root_password host]
make backup filepath [db root_password host ignore]
make backup-stream stream_path status_path [db root_password host ignore]
```

Example:

```bash
docker run --rm \
  --link mysql:mysql \
  -e MYSQL_ROOT_PASSWORD=password \
  wodby/mysql:8.4 \
  make check-ready host=mysql max_try=30 wait_seconds=2
```

## Development

```bash
make
make test
```

The wrapper code is licensed under GPL-2.0. MySQL Community Server and bundled
dependencies retain their respective upstream licenses.

## Building with pinned base images

Build with the Makefile to use the base image digests in `base-images.mk`. Local
builds and CI resolve the same version and variant to the same multi-platform
image. A version without a pin fails before the build starts.

When adding a supported base version or variant, add its image index digest to
`base-images.mk`. For a custom build, override `BASE_IMAGE` with a complete
`repository:tag@sha256:...` reference.
