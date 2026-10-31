#!/usr/bin/env bash

# bumps the PATCH part of VERSION, so a renovate pull request releases a new version when merged

set -euo pipefail

version=$(tr -d '[:space:]' < VERSION)
if ! [[ $version =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    echo "VERSION must be MAJOR.MINOR.PATCH, not '$version'" >&2
    exit 1
fi

printf '%s.%s.%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "$((BASH_REMATCH[3] + 1))" > VERSION
