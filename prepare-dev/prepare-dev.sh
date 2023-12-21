#!/bin/bash
set -eou pipefail
set -x
IFS=$'\n\t'

if [[ "${DRY_RUN:-}" == 1 ]]; then
    echo "Dry Run. Will not Push."
fi

# shellcheck disable=SC2155
readonly SELF_DIRNAME="$(dirname -- "$0")"

# TODO: Parameterize or make case-insensitive when this is an action
# shellcheck disable=SC2034
readonly GIT_USER="bot@getpantheon.com"
# shellcheck disable=SC2034
readonly GIT_NAME="Pantheon Automation"

# shellcheck disable=SC1091
source "${SELF_DIRNAME}/src/functions.sh"

readonly RELEASE_BRANCH="release"
readonly DEVELOP_BRANCH="main"

main() {
    local README_MD="${1:-}"
    if [[ -z "$README_MD" ]]; then
        README_MD=README.MD
    fi

    local CURRENT_VERSION
    CURRENT_VERSION="$(grep 'Stable tag:' < "${README_MD}" | awk '{print $3}')"

    # fetch all tags and history:
    git fetch --tags --unshallow --prune
    git branch --track main origin/main

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