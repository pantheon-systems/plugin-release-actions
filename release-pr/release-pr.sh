#!/bin/bash
set -eou pipefail
IFS=$'\n\t'

# shellcheck disable=SC2155
readonly SELF_DIRNAME="$(dirname -- "$0")"

# shellcheck disable=SC1091
source "${SELF_DIRNAME}/../src/functions.sh"

main() {
	local README_MD="${1:-}"
    if [[ -z "$README_MD" ]]; then
        README_MD=README.MD
    fi

    local CURRENT_VERSION
    CURRENT_VERSION="$(grep 'Stable tag:' < "${README_MD}" | awk '{print $3}')"

    local NEW_VERSION="${CURRENT_VERSION%-dev}"
    local RELEASE_BRANCH="release-${NEW_VERSION}"

    # if local release branch exists, delete it
    if git show-ref --quiet --verify "refs/heads/$RELEASE_BRANCH"; then
        echo "> git branch -D ${RELEASE_BRANCH}"
        git branch -D "${RELEASE_BRANCH}"
    fi

    git checkout -b "${RELEASE_BRANCH}"
    echo "Updating ${CURRENT_VERSION} to ${NEW_VERSION}"
    # Iterate through each file in the top-level directory
    for file in ./*; do
        process_file "$file" "${CURRENT_VERSION}" "${NEW_VERSION}"
    done

    git_config

    RELEASE_MESSAGE="Release ${NEW_VERSION}"
    git commit -m "${RELEASE_MESSAGE}"
    git push origin "${RELEASE_BRANCH}" --force

    # Create a draft PR
    create_draft_pr RELEASE_MESSAGE
    if gh pr view "${RELEASE_BRANCH}"; then
    	echo_info "PR Already Exists"
    	return
    fi
    local PR_TITLE="${RELEASE_MESSAGE}"
    local PR_BODY="${RELEASE_MESSAGE}. If CI tests have not run, mark as 'ready for review' or close this PR and re-open it.

For proper management of git history, merge this PR, do not squash or rebase."
    gh pr create --draft --base "release" \
        --title "${PR_TITLE}" --body "${PR_BODY}" \
        --label "automation"
}

main "$@"