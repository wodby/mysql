#!/usr/bin/env bash

set -euo pipefail

IMAGE="${IMAGE:-wodby/mysql:8.4}"
GHOST_IMAGE="${GHOST_IMAGE:-ghost:6.63.0}"
test_name="mysql-ghost-test-$$"
db_name="${test_name}-db"
ghost_name="${test_name}-app"

cleanup() {
    docker rm -fv "${ghost_name}" "${db_name}" >/dev/null 2>&1 || true
    docker network rm "${test_name}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker network create "${test_name}" >/dev/null
docker run -d --name "${db_name}" --network "${test_name}" \
    -e MYSQL_ROOT_PASSWORD=root-test-password \
    -e MYSQL_DATABASE=ghost -e MYSQL_USER=ghost -e MYSQL_PASSWORD=ghost-test-password \
    "${IMAGE}" >/dev/null
docker exec "${db_name}" make -f /usr/local/bin/actions.mk check-ready max_try=60 wait_seconds=2

# Exercise Ghost's production driver, initial migrations, and HTTP startup.
docker run -d --name "${ghost_name}" --network "${test_name}" \
    -e NODE_ENV=production -e url=http://localhost:2368 \
    -e database__client=mysql -e "database__connection__host=${db_name}" \
    -e database__connection__user=ghost -e database__connection__password=ghost-test-password \
    -e database__connection__database=ghost -e mail__from=ghost@example.com \
    "${GHOST_IMAGE}" >/dev/null

for ((attempt=0; attempt<60; attempt++)); do
    if docker exec "${ghost_name}" node -e '
        const http = require("http");
        const req = http.get("http://127.0.0.1:2368/", res => {
            res.resume();
            process.exit(res.statusCode === 200 ? 0 : 1);
        });
        req.setTimeout(2000, () => req.destroy());
        req.on("error", () => process.exit(1));
    ' >/dev/null 2>&1; then
        echo 'Ghost production migrations and HTTP startup passed on MySQL 8.4'
        exit 0
    fi
    if [[ "$(docker inspect -f '{{.State.Running}}' "${ghost_name}")" != true ]]; then
        break
    fi
    sleep 2
done

docker logs "${db_name}"
docker logs "${ghost_name}"
echo 'Ghost failed to start on MySQL 8.4' >&2
exit 1
