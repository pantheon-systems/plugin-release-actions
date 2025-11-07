#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

if [[ "${DRY_RUN:-}" == 1 ]]; then
    echo "Dry Run. Will not Push."
fi

# shellcheck disable=SC2155
readonly SELF_DIRNAME="$(dirname -- "$0")"

# Get configuration from environment variables or use defaults
declare -rx GIT_USER="${GIT_AUTHOR_EMAIL:-bot@getpantheon.com}"
declare -rx GIT_NAME="${GIT_AUTHOR_NAME:-Pantheon Automation}"

# shellcheck disable=SC1091
source "${SELF_DIRNAME}/../src/functions.sh"

readonly RELEASE_BRANCH="${RELEASE_BRANCH:-release}"
readonly DEVELOP_BRANCH="${DEVELOPMENT_BRANCH:-main}"

main() {
    local README_MD="${1:-}"
    if [[ -z "$README_MD" ]]; then
        README_MD=README.MD
    fi

    local CURRENT_VERSION
    CURRENT_VERSION="$(grep 'Stable tag:' < "${README_MD}" | awk '{print $3}')"

    # fetch all tags and history:
    git fetch --tags --unshallow --prune
    
    # Set up tracking for development branch if it doesn't exist
    if ! git show-ref --verify --quiet "refs/heads/${DEVELOP_BRANCH}"; then
        git branch --track "${DEVELOP_BRANCH}" "origin/${DEVELOP_BRANCH}"
    fi

    git checkout "${RELEASE_BRANCH}"
    git pull origin "${RELEASE_BRANCH}"
    git checkout "${DEVELOP_BRANCH}"
    git pull origin "${DEVELOP_BRANCH}"
    git rebase "${RELEASE_BRANCH}"

    local NEW_DEV_VERSION
    NEW_DEV_VERSION=$(new_dev_version_from_current "$CURRENT_VERSION")

    echo "Updating ${CURRENT_VERSION} to ${NEW_DEV_VERSION}"
    # Iterate through each file in the top-level directory
    for file in ./*; do
        process_file "$file" "${CURRENT_VERSION}" "${NEW_DEV_VERSION}"
    done

    git_config

    git commit -m "Prepare ${NEW_DEV_VERSION}"

    if [[ "${DRY_RUN:-}" == 1 ]]; then
        return
    fi
    git push origin "${DEVELOP_BRANCH}"
}

main "$@"