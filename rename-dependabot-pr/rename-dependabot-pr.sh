#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

ecosystem_label() {
    case "$1" in
        composer)       echo "Composer" ;;
        npm)            echo "npm" ;;
        github-actions) echo "GitHub Actions" ;;
        gomod)          echo "Go" ;;
        docker)         echo "Docker" ;;
        *)              echo "$1" ;;
    esac
}

main() {
    if [[ -z "${PR_TITLE:-}" || -z "${PR_URL:-}" ]]; then
        echo "PR_TITLE and PR_URL environment variables must be set"
        exit 1
    fi

    # The rename fires an `edited` event, and only Dependabot's titles carry the verb.
    if [[ ! "${PR_TITLE}" =~ [Bb]ump\  ]]; then
        echo "Not a title Dependabot generated, leaving it alone: ${PR_TITLE}"
        exit 0
    fi

    local GROUP PREFIX SUMMARY
    GROUP=$(sed -n 's/.* the \([^ ]*\) group.*/\1/p' <<<"${PR_TITLE}")

    case "${GROUP}" in
        # Minor and patch are grouped, so an ungrouped PR is a major.
        "")            PREFIX="Major update" ;;
        *-security)    PREFIX="Security update" ;;
        *-minor-patch) PREFIX="$(ecosystem_label "${GROUP%-minor-patch}") minor" ;;
        *)             PREFIX="${GROUP}" ;;
    esac

    # Dependabot writes "with N updates" only when a group batches two or more.
    SUMMARY=$(sed -n 's/.*with \([0-9]* update[s]*\).*/\1/p' <<<"${PR_TITLE}")
    if [[ -z "${SUMMARY}" ]]; then
        SUMMARY=$(sed -E 's/^[^:]*: //; s/^[Bb]ump //; s/ in the [^ ]+ group.*$//; s/^the [^ ]+ group to /update to /; s/ from / /' <<<"${PR_TITLE}")
    fi

    if [[ -z "${SUMMARY}" ]]; then
        echo "::notice::Title left as it is, no summary could be read out of: ${PR_TITLE}"
        exit 0
    fi

    echo "Renaming to: ${PREFIX}: ${SUMMARY}"
    gh pr edit "${PR_URL}" --title "${PREFIX}: ${SUMMARY}"
}

main
