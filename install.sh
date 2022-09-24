#!/usr/bin/env bash

getopt --test >/dev/null
if [[ ${?} -ne 4 ]]; then
    printf "Missing the right `getopt` version.\n" >&2
    exit 1
fi

set -euo pipefail
IFS=$'\n\t'

# Include libs.
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source ${SCRIPT_DIR}/my-bins/.local/bin/libs/pkg-mgrs
source ${SCRIPT_DIR}/my-bins/.local/bin/libs/password-utilities

function __run_stow_cmd() {
    local result=(stow)
    $OPT_DRY_RUN && result+=(--no --verbose) || true
    $OPT_REINSTALL && result+=("--restow") || true
    $OPT_DELETE && result+=("--delete") || true
    result+=(--target="${OPT_TARGET_DIR}")

    "${result[@]}" "$@"
}

function __install_dep() {
    if $OPT_DRY_RUN; then
        printf "INSTALL: "
        $OPT_NO_SU || printf "sudo "
        printf "%s " "$@"
        printf "\n"
    else
        if $OPT_NO_SU; then
            "$@"
        else
            sudo_exec "$@"
        fi
    fi
}

function main() {
    # Dir verification
    local dirs=("$@")
    local halt="false"
    for dir in "${dirs[@]}"; do
        verify_dir $dir || halt="true"
    done
    $halt && exit 1 || true

    # Gather the dependencies that aren't already installed.
    local dependencies_to_install=()
    local dependency_install_cmds=()
    for dir in "${dirs[@]}"; do
        [[ -f ${dir}.yml ]] || continue

        local deps=($(get_pkgs_to_install "${dir}.yml"))
        for dep in "${deps[@]}"; do
            install_cmd="$(get_pkg_install_cmd "${dir}.yml" "${dep}")"
            if [[ -z ${install_cmd} ]]; then
                dependencies_to_install+=("${dep}")
            else
                dependency_install_cmds+=("${install_cmd}")
            fi
        done
    done

    # Install them.
    if [[ ${#dependencies_to_install[@]} -gt 0 ]]; then
        __install_dep "${OPT_INSTALL_PKG_CMD[@]}" "${dependencies_to_install[@]}"
    fi
    for install_cmd in "${dependency_install_cmds[@]}"; do
        __install_dep "${install_cmd[@]}"
    done

    __run_stow_cmd "${dirs[@]}"
}


function show_help() {
    cat <<EOF
Usage: ${0##*/} [options] <dir>...
Given a folder, this will install all dependencies specified for it, then create
symlinks to all the files within the listed dirs into your home directory.

Commands:
  -t | --target=DIR         If specified, this is the directory to install to.
                            This defaults to your HOME directory.
  -n | --dry-run            Don't actually do anything, just show what would
                            happen.
  -r | --reinstall          Delete the symlinks, then recreate them. This is
                            typically used when you've updated the files in a
                            dir.
  -d | --delete             Deletes the symlinks, but NOT the dependencies.
  -i | --install-pkg-cmd    Override the command used to install dependencies.
                            Defaults to whatever makes sense for your platform.
  -s | --no-su              Do not execute the given --install-pkg-cmd as the
                            super user. This is necessary for some package
                            managers that build as a normal user then install.
  -h | --help               Display this help message.
EOF
}

function verify_dir() {
    local dir="${1}"

    if ! [[ -d $dir ]]; then
        printf "Specified directory '$dir' does not exist.\n" >&2
        return 1
    fi
    return 0
}

SHORT_OPTIONS="hnrdt:i:s"
LONG_OPTIONS="help,dry-run,reinstall,delete,target:,install-pkg-cmd:,no-su"
PARSED_ARGS=$(getopt \
    --options="${SHORT_OPTIONS}" \
    --longoptions="${LONG_OPTIONS}" \
    --name ${0##*/} \
    -- "$@")
if [[ ${?} -ne 0 ]]; then
    # Getopt has complained about invalid arguments.
    exit 2
fi

DIRS=()
OPT_DRY_RUN="false"
OPT_REINSTALL="false"
OPT_DELETE="false"
OPT_NO_SU="false"
OPT_TARGET_DIR="${HOME}"
OPT_INSTALL_PKG_CMD=$( get_pkg_cmd install )
eval set -- "${PARSED_ARGS}"
while [[ ${#} -gt 0 ]]; do
    case "${1}" in
        -n|--dry-run)   OPT_DRY_RUN="true";;
        -r|--reinstall) OPT_REINSTALL="true";;
        -d|--delete)    OPT_DELETE="true";;
        -s|--no-su)     OPT_NO_SU="true";;
        -t|--target)    OPT_TARGET_DIR="${2}"; shift;;
        -i|--install-pkg-cmd)
                        OPT_INSTALL_PKG_CMD="${2}"; shift;;
        -h|--help)
            show_help
            exit 0
            ;;
        --)
            shift
            DIRS+=("$@")
            break
            ;;
        *)
            printf "Scripting error.\n" >&2
            exit 1
            ;;
    esac
    shift
done

if [[ ${#DIRS[@]} -eq 0 ]]; then
    printf "Error: No dir specified for installation. Aborting.\n\n" >&2
    show_help
    exit 1
fi

main "${DIRS[@]}"
