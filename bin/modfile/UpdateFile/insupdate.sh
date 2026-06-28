#!/usr/bin/env bash
set -uo pipefail

work_dir=$(pwd)
source "$work_dir/functions.sh"

mods "Starting Update File..."
TARGET_DIR="$work_dir/bin/modfile/UpdateFile"
SCRIPT_TIMEOUT_SECONDS="${UPDATEFILE_SCRIPT_TIMEOUT_SECONDS:-900}"

updatefile_log() {
    if declare -F mods >/dev/null 2>&1; then
        mods "$1"
    else
        echo "$1"
    fi
}

should_skip_script() {
    local rel_path="$1"
    local base_name
    base_name="$(basename "$rel_path")"

    [[ "$base_name" == "insupdate.sh" ]] && return 0
    [[ "$rel_path" == *"__pycache__"* ]] && return 0
    [[ "$base_name" == *.bak.sh ]] && return 0
    [[ "$base_name" == *.disabled.sh ]] && return 0
    [[ "$base_name" == *~ ]] && return 0

    return 1
}

run_script() {
    local script="$1"
    local rel_path="${script#"$TARGET_DIR"/}"
    local start_ts end_ts duration exit_code
    local timeout_used=0

    if should_skip_script "$rel_path"; then
        updatefile_log "[UpdateFile] SKIP: $rel_path"
        return 0
    fi

    start_ts=$(date +%s)
    updatefile_log "[UpdateFile] START: $rel_path"

    if command -v timeout >/dev/null 2>&1; then
        timeout_used=1
        timeout "$SCRIPT_TIMEOUT_SECONDS" bash "$script"
        exit_code=$?
    else
        bash "$script"
        exit_code=$?
    fi

    end_ts=$(date +%s)
    duration=$((end_ts - start_ts))

    if [[ $exit_code -eq 0 ]]; then
        updatefile_log "[UpdateFile] DONE: $rel_path (${duration}s)"
        return 0
    fi

    if [[ $timeout_used -eq 1 && $exit_code -eq 124 ]]; then
        updatefile_log "[UpdateFile] TIMEOUT: $rel_path after ${SCRIPT_TIMEOUT_SECONDS}s"
        return 124
    fi

    updatefile_log "[UpdateFile] FAIL: $rel_path exit=$exit_code (${duration}s)"
    return "$exit_code"
}

mapfile -t scripts < <(find "$TARGET_DIR" -type f -name "*.sh" | LC_ALL=C sort)

for script in "${scripts[@]}"; do
    run_script "$script" || exit $?
done
