#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Dependabot cannot put the update type in a title it generates, so the group
# name is the only place the type appears.

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

    # The rename fires an `edited` event, which runs this again on its own output.
    # Every title Dependabot generates carries the verb, and none of ours does.
    if [[ ! "${PR_TITLE}" =~ [Bb]ump\  ]]; then
        echo "Not a title Dependabot generated, leaving it alone: ${PR_TITLE}"
        exit 0
    fi

    local PREFIX SUMMARY
    if [[ "${PR_TITLE}" == *" group with"* ]]; then
        local GROUP
        GROUP=$(sed -n 's/.*the \(.*\) group with.*/\1/p' <<<"${PR_TITLE}")
        if [[ -z "${GROUP}" ]]; then
            echo "Could not read a group name out of: ${PR_TITLE}"
            exit 1
        fi

        case "${GROUP}" in
            *-security)    PREFIX="Security update" ;;
            *-minor-patch) PREFIX="$(ecosystem_label "${GROUP%-minor-patch}") minor" ;;
            *)             PREFIX="${GROUP}" ;;
        esac

        SUMMARY=$(sed -n 's/.*with \([0-9]* update[s]*\).*/\1/p' <<<"${PR_TITLE}")
    else
        # Minor and patch are grouped, so an ungrouped PR is a major.
        PREFIX="Major update"
        SUMMARY=$(sed -E 's/^.*[Bb]ump //; s/ from / /' <<<"${PR_TITLE}")
    fi

    if [[ -z "${SUMMARY}" ]]; then
        echo "Could not read a summary out of: ${PR_TITLE}"
        exit 1
    fi

    echo "Renaming to: ${PREFIX}: ${SUMMARY}"
    gh pr edit "${PR_URL}" --title "${PREFIX}: ${SUMMARY}"
}

main
