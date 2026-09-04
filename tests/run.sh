#!/usr/bin/env bash

set -euo pipefail

if [[ -n "${DEBUG:-}" ]]; then
    set -x
fi

IMAGE="${IMAGE:-wodby/mysql:8.0}"
NAME="${NAME:-mysql-8.0}"
test_id="$$"
server_name="${NAME}-test-${test_id}"
data_volume="${server_name}-data"
work_dir="$(mktemp -d)"
backup_dir="${work_dir}/backup"
init_dir="${work_dir}/init"
mkdir -p "${backup_dir}" "${init_dir}"
chmod 777 "${backup_dir}"

export MYSQL_ROOT_PASSWORD='root-test-password'
export MYSQL_USER='mysql_test'
export MYSQL_PASSWORD='mysql-test-password'
export MYSQL_DATABASE='mysql_test'

cleanup() {
    docker rm -f "${server_name}" >/dev/null 2>&1 || true
    docker volume rm "${data_volume}" >/dev/null 2>&1 || true
    rm -rf "${work_dir}"
}
trap cleanup EXIT

printf '%s\n' \
    'CREATE TABLE mysql_test.init_archive_test (id INT PRIMARY KEY);' \
    'INSERT INTO mysql_test.init_archive_test VALUES (1);' \
    > "${init_dir}/database.sql"
tar -czf "${init_dir}/database.tar.gz" -C "${init_dir}" database.sql
rm "${init_dir}/database.sql"

docker volume create "${data_volume}" >/dev/null
docker run -d \
    --name "${server_name}" \
    -e MYSQL_ROOT_PASSWORD \
    -e MYSQL_USER \
    -e MYSQL_PASSWORD \
    -e MYSQL_DATABASE \
    -e MYSQL_MAX_CONNECTIONS=73 \
    -v "${data_volume}:/var/lib/mysql" \
    -v "${init_dir}:/wodby/import:ro" \
    "${IMAGE}" >/dev/null

mysql_image() {
    docker run --rm \
        -e MYSQL_ROOT_PASSWORD \
        -e MYSQL_USER \
        -e MYSQL_PASSWORD \
        -e MYSQL_DATABASE \
        -v "${backup_dir}:/mnt" \
        --link "${server_name}:mysql" \
        "${IMAGE}" \
        "$@" \
        host=mysql
}

mysql_image make check-ready max_try=30 wait_seconds=2
[ "$(mysql_image make query-silent query='SELECT COUNT(*) FROM init_archive_test')" = '1' ]
[ "$(mysql_image make query-silent user=root password="${MYSQL_ROOT_PASSWORD}" db=mysql query='SELECT @@max_connections')" = '73' ]
[[ "$(mysql_image make query-silent user=root password="${MYSQL_ROOT_PASSWORD}" db=mysql query='SELECT VERSION()')" == 8.0.44* ]]

mysql_image make create-db name=lifecycle charset=utf8mb4 collation=utf8mb4_0900_ai_ci
mysql_image make create-user username=lifecycle_user password=lifecycle-password
mysql_image make create-user username=lifecycle_user password=lifecycle-password
if mysql_image make create-user username=lifecycle_user password=unexpected-password; then
    echo 'create-user unexpectedly replaced an existing password' >&2
    exit 1
fi
mysql_image make grant-user-db username=lifecycle_user db=lifecycle
mysql_image make query user=lifecycle_user password=lifecycle-password db=lifecycle \
    query='CREATE TABLE contract_check (id INT PRIMARY KEY); INSERT INTO contract_check VALUES (1);'
[ "$(mysql_image make query-silent user=lifecycle_user password=lifecycle-password db=lifecycle query='SELECT COUNT(*) FROM contract_check')" = '1' ]
mysql_image make mysql-check db=lifecycle
mysql_image make revoke-user-db username=lifecycle_user db=lifecycle
mysql_image make drop-user username=lifecycle_user
mysql_image make drop-db name=lifecycle

mysql_image make query query='CREATE TABLE retained (id INT PRIMARY KEY); INSERT INTO retained VALUES (1);'
mysql_image make query query='CREATE TABLE cache_rows (id INT PRIMARY KEY); INSERT INTO cache_rows VALUES (1);'
mysql_image make backup filepath=/mnt/export.sql.gz ignore='cache_%'
test -s "${backup_dir}/export.sql.gz"
mysql_image make import source=/mnt/export.sql.gz
[ "$(mysql_image make query-silent query='SELECT COUNT(*) FROM retained')" = '1' ]
[ "$(mysql_image make query-silent query='SELECT COUNT(*) FROM cache_rows')" = '0' ]

stream_dir="${work_dir}/stream"
mkdir "${stream_dir}"
chmod 777 "${stream_dir}"
docker run --rm \
    -e MYSQL_ROOT_PASSWORD \
    -e MYSQL_USER \
    -e MYSQL_PASSWORD \
    -e MYSQL_DATABASE \
    -v "${stream_dir}:/stream" \
    --link "${server_name}:mysql" \
    "${IMAGE}" bash -ceu '
        mkfifo /stream/data
        touch /stream/status
        chmod 666 /stream/data /stream/status
        cat /stream/data > /stream/export.sql.gz &
        reader=$!
        make -f /usr/local/bin/actions.mk backup-stream \
            host=mysql \
            stream_path=/stream/data \
            status_path=/stream/status
        wait "${reader}"
        test "$(cat /stream/status)" = 0
    '
test -s "${stream_dir}/export.sql.gz"

docker rm -f "${server_name}" >/dev/null
docker run -d \
    --name "${server_name}" \
    -e MYSQL_ROOT_PASSWORD \
    -e MYSQL_USER \
    -e MYSQL_PASSWORD \
    -e MYSQL_DATABASE \
    -e MYSQL_MAX_CONNECTIONS=73 \
    -v "${data_volume}:/var/lib/mysql" \
    "${IMAGE}" >/dev/null
mysql_image make check-ready max_try=30 wait_seconds=2
[ "$(mysql_image make query-silent query='SELECT COUNT(*) FROM retained')" = '1' ]

echo 'MySQL image runtime contract passed'
