#!/usr/bin/env bash

getopt --test >/dev/null
if [[ ${?} -ne 4 ]]; then
    printf "Missing the right 'getopt' version.\n" >&2
    exit 1
fi

set -euo pipefail
IFS=$'\n\t'

# Include libs.
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
SCRIPT_NAME="$( basename "${BASH_SOURCE[0]}" )"
SCRIPT_DATA="${SCRIPT_DIR}/${SCRIPT_NAME%.*}.yml"
source ${SCRIPT_DIR}/my-bins/.local/bin/libs/pkg-mgrs

# I use this on a work computer and I'd rather keep my work contact
# info out of this.
function configure_gitname() {
    git config user.name squatched
    git config user.email squatched@user.noreply.github.com
}

function main() {
    configure_gitname
    ensure_pkgs_installed "${SCRIPT_DATA}" "${OPT_INSTALL_PKG_CMD[@]}"
}

function show_help() {
    cat <<EOF
Usage: ${0##*/} [options]
Bootstrap some git settings for this repo and ensure dependencies are met.

Commands:
  -i | --install-pkg-cmd    Override the default package installation command.
  -h | --help               Display this help message.
EOF
}

SHORT_OPTIONS="i:h"
LONG_OPTIONS="install-pkg-cmd:,help"
PARSED_ARGS=$(getopt \
    --options="${SHORT_OPTIONS}" \
    --longoptions="${LONG_OPTIONS}" \
    --name ${0##*/} \
    -- "$@")
if [[ ${?} -ne 0 ]]; then
    # Getopt has complained about invalid arguments.
    exit 2
fi

OPT_INSTALL_PKG_CMD=""
eval set -- "${PARSED_ARGS}"
while [[ ${#} -gt 0 ]]; do
    case "${1}" in
        -i|--install-pkg-cmd)   OPT_INSTALL_PKG_CMD="${2}"; shift;;
        -h|--help)
            show_help
            exit 0
            ;;
        --)
            shift
            break
            ;;
        *)
            printf "Scripting error.\n" >&2
            exit 1
            ;;
    esac
    shift
done

[[ -z ${OPT_INSTALL_PKG_CMD} ]] && OPT_INSTALL_PKG_CMD=$( get_pkg_cmd install )

main
