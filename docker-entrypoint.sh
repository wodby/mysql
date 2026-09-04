#!/usr/bin/env bash

set -euo pipefail

if [[ -n "${DEBUG:-}" ]]; then
    set -x
fi

config_file="${WODBY_MYSQL_CONFIG_FILE:-/etc/mysql/conf.d/zz-wodby.cnf}"
config_dir="$(dirname "${config_file}")"
mkdir -p "${config_dir}"

config_tmp="$(mktemp "${config_dir}/.wodby.cnf.XXXXXX")"
cleanup() {
    rm -f "${config_tmp}"
}
trap cleanup EXIT

gotpl /etc/gotpl/my.cnf.tmpl > "${config_tmp}"
chmod 0644 "${config_tmp}"
mv "${config_tmp}" "${config_file}"
trap - EXIT

if [[ "${1:-}" == "make" ]]; then
    shift
    exec make -f /usr/local/bin/actions.mk "$@"
fi

exec /usr/local/bin/docker-entrypoint.sh "$@"
