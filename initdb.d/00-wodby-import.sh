#!/usr/bin/env bash

# This file is sourced by the upstream MySQL entrypoint during first-time
# initialization, which gives it access to docker_process_sql.

wodby_process_import() {
    local import_dir=/wodby/import
    local tmp_dir
    local -a import_sources=()
    local -a sql_files=()

    [[ -d "${import_dir}" ]] || return 0
    mapfile -d '' import_sources < <(
        find "${import_dir}" -maxdepth 1 -type f \
            ! -name '._*' \
            -print0
    )

    [[ "${#import_sources[@]}" -gt 0 ]] || return 0
    if [[ "${#import_sources[@]}" -ne 1 ]]; then
        mysql_error "Expected exactly one initialization import; found ${#import_sources[@]}"
    fi

    tmp_dir="$(mktemp -d /tmp/mysql-init-import.XXXXXX)"
    get_archive "${import_sources[0]}" "${tmp_dir}"
    mapfile -d '' sql_files < <(
        find "${tmp_dir}" -type f \
            \( -name '*.sql' -o -name '*.mysql' \) \
            ! -name '._*' \
            ! -path '*/__MACOSX/*' \
            -print0
    )

    if [[ "${#sql_files[@]}" -ne 1 ]]; then
        mysql_error "Expected exactly one .sql or .mysql initialization file; found ${#sql_files[@]}"
    fi

    mysql_note "Importing ${import_sources[0]}"
    docker_process_sql < "${sql_files[0]}"
    rm -rf "${tmp_dir}"
}

wodby_process_import
unset -f wodby_process_import
