#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

trim_patch_version() {
    echo "$1" | awk -F. '{print $1"."$2}'
}

main() {
    export TERMINUS_HIDE_GIT_MODE_WARNING=1

    if [[ -z "${TERMINUS_SITE:-}" ]]; then
        echo "TERMINUS_SITE environment variable must be set"
        exit 1
    fi

    if ! terminus whoami > /dev/null 2>&1; then
        if [[ -z "${TERMINUS_TOKEN:-}" ]]; then
            echo "TERMINUS_TOKEN environment variable must be set or terminus already logged in."
            exit 1
        fi
        terminus auth:login --machine-token="${TERMINUS_TOKEN}"
    fi

    local CURRENT_WP_VERSION
    CURRENT_WP_VERSION=$(curl -s https://api.wordpress.org/core/version-check/1.7/ | jq -r '.offers[0].current')
    echo "Current WordPress Version: ${CURRENT_WP_VERSION}"

    local README_FILE_PATH="${README_TXT:-readme.txt}"
    if [[ ! -f "${README_FILE_PATH}" ]]; then
        echo "readme.txt not found at: ${README_FILE_PATH}"
        exit 1
    fi

    local TESTED_UP_TO
    TESTED_UP_TO=$(grep -i "Tested up to:" "${README_FILE_PATH}" | tr -d '\r\n' | awk -F ': ' '{ print $2 }')
    echo "Tested Up To: ${TESTED_UP_TO}"

    local FIXTURE_VERSION
    FIXTURE_VERSION=$(terminus wp "${TERMINUS_SITE}.dev" -- core version)
    echo "Fixture Version: ${FIXTURE_VERSION}"

    local FIXTURE_VERSION_COMPARE
    FIXTURE_VERSION_COMPARE=$(php -r "echo version_compare('${FIXTURE_VERSION}', '${CURRENT_WP_VERSION}');")
    if [[ "${FIXTURE_VERSION_COMPARE}" == "-1" ]]; then
        echo "Fixture Version: ${FIXTURE_VERSION} is less than Current WordPress Version: ${CURRENT_WP_VERSION}"
        echo "Applying upstream updates on ${TERMINUS_SITE}"
        terminus upstream:updates:apply "${TERMINUS_SITE}.dev" --accept-upstream --updatedb
    fi

    local CURRENT_WP_VERSION_TRIMMED
    CURRENT_WP_VERSION_TRIMMED=$(trim_patch_version "${CURRENT_WP_VERSION}")
    local FIXTURE_VERSION_TRIMMED
    FIXTURE_VERSION_TRIMMED=$(trim_patch_version "${FIXTURE_VERSION}")

    local WP_VERSION_COMPARE
    WP_VERSION_COMPARE=$(php -r "echo version_compare('${TESTED_UP_TO}', '${CURRENT_WP_VERSION_TRIMMED}');")

    if [[ "${WP_VERSION_COMPARE}" == "0" ]]; then
        echo "Tested Up To: ${TESTED_UP_TO} matches Current WordPress Version: ${CURRENT_WP_VERSION} (trimmed: ${CURRENT_WP_VERSION_TRIMMED})"
    elif [[ "${WP_VERSION_COMPARE}" == "1" ]]; then
        echo "Tested Up To: ${TESTED_UP_TO} is greater than Current WordPress Version: ${CURRENT_WP_VERSION}"
    else
        echo "Tested Up To: ${TESTED_UP_TO} does not match Current WordPress Version: ${CURRENT_WP_VERSION} (trimmed: ${CURRENT_WP_VERSION_TRIMMED})"
        echo "Please update ${TESTED_UP_TO} to ${CURRENT_WP_VERSION_TRIMMED}"
        exit 1
    fi

    local VERSION_COMPARE
    VERSION_COMPARE=$(php -r "echo version_compare('${TESTED_UP_TO}', '${FIXTURE_VERSION_TRIMMED}');")

    if [[ "${VERSION_COMPARE}" == "0" ]]; then
        echo "Tested Up To: ${TESTED_UP_TO} matches Fixture Version: ${FIXTURE_VERSION} (trimmed: ${FIXTURE_VERSION_TRIMMED})"
        exit 0
    fi

    if [[ "${VERSION_COMPARE}" == "-1" ]]; then
        echo "${TESTED_UP_TO} is less than ${FIXTURE_VERSION} (trimmed: ${FIXTURE_VERSION_TRIMMED})"
        echo "Please update ${TESTED_UP_TO} to ${FIXTURE_VERSION_TRIMMED}"
        exit 1
    fi

    if [[ "${VERSION_COMPARE}" == "1" ]]; then
        echo "${FIXTURE_VERSION} (trimmed: ${FIXTURE_VERSION_TRIMMED}) is less than ${TESTED_UP_TO}"

        local CURRENT_MAJOR CURRENT_MINOR
        read -r CURRENT_MAJOR CURRENT_MINOR <<<"$(echo "${CURRENT_WP_VERSION}" | awk -F. '{print $1, $2}')"
        local NEXT_MAJOR_VERSION="${CURRENT_MAJOR}.$((CURRENT_MINOR + 1))"

        if [[ "${TESTED_UP_TO}" == "${NEXT_MAJOR_VERSION}" ]]; then
            echo "Tested Up To: ${TESTED_UP_TO} is the next major version after the Current WordPress Version: ${CURRENT_WP_VERSION}"
            echo "Ensure you have validated that the plugin works on the next major version of WordPress or update ${TERMINUS_SITE} to a pre-release version."
        else
            echo "Tested Up To: ${TESTED_UP_TO} is not the next major version (${NEXT_MAJOR_VERSION}). This seems like an error. Please review."
            exit 1
        fi
    fi
}

main
