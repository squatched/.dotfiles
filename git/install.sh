#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

# Super simple, just include the files in this directory.
 SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

git config --global include.path "${SCRIPT_DIR}/gitconfig-include"
