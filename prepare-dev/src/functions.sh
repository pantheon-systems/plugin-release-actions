#!/bin/bash
# no flags here, always source this file

# echo to stderr with info tag
echo_info(){
	echo  "[Info] $*" >&2
}

# echo to stderr with info tag
echo_error(){
	echo  "[Error] $*" >&2
}

new_dev_version_from_current(){
    local CURRENT_VERSION="${1:-}"
    if [[ -z "$CURRENT_VERSION" ]]; then
		echo_error "No version passed to new_dev_version_from_current()"
    	return 1
    fi

    IFS='.' read -ra parts <<< "$CURRENT_VERSION"
    local patch="${parts[2]}"
    patch=$((patch + 1))
    local INCREMENTED="${parts[0]}.${parts[1]}.${patch}-dev"
    echo "$INCREMENTED"
}

git_config(){
    git config user.email "${GIT_USER}"
    git config user.name "${GIT_NAME}"
}


process_file(){
    local FILE="${1:-}"
    local OLD_VERSION="${2:-}"
    local NEW_VERSION="${3:-}"
    if [[ -z "${FILE}" ]] || [[ ! -f "$FILE" ]]; then
        echo_info "No File '${FILE}'"
        return
    fi
    # Convert the filename to lowercase for case-insensitive comparison
    LC_FILE_PATH=$(echo "$FILE" | tr '[:upper:]' '[:lower:]')

    echo "Processing file '${FILE}'..."
    if [[ "$LC_FILE_PATH" == *"/package-lock.json" ]];then
        echo_info "skip package-lock [${FILE}]."
        return
    fi
    if [[  "$LC_FILE_PATH" == *"/package.json" ]]; then
        echo_info "Updating package with 'npm version'"
        npm version "${NEW_DEV_VERSION}" --no-git-tag-version
        git add "$FILE"
        git add "$(dirname "$FILE")/package-lock.json"
        return
    fi

    if [[ "$LC_FILE_PATH" == *"/composer.json" || "$LC_FILE_PATH" == *"/composer.lock" ]];then
        echo_info "skip composer [${FILE}]."
        return
    fi
    if [[ "$LC_FILE_PATH" == *readme.* ]]; then
        echo_info "Alternative readme Processing  [${FILE}]."
        update_readme "${FILE}" "${OLD_VERSION}" "${NEW_VERSION}"
        echo_info "Skip futher readme sed"
        return
    fi

    echo "search-and-replace with sed"
    sed -i.tmp -e '/^\s*\* @since/!s/'"${OLD_VERSION}"'/'"${NEW_VERSION}"'/g' "$FILE" && rm "$FILE.tmp"

    git add "$FILE"
}

update_readme(){
    local FILE_PATH="${1:-}"
    local OLD_VERSION="${2:-}"
    local NEW_VERSION="${3:-}"
    if [[ -z "${FILE_PATH}" || -z "${OLD_VERSION}" || -z "${NEW_VERSION}" ]]; then
        echo_error "usage: update_readme FILE_PATH OLD_VERSION NEW_VERSION"
        return 1
    fi
    
    # Convert the filename to lowercase for case-insensitive comparison
    LC_FILE_PATH=$(echo "$FILE_PATH" | tr '[:upper:]' '[:lower:]')

    if [[ "$LC_FILE_PATH" == *.md ]]; then
        echo_info "markdown search-replace"
        local new_heading="### ${NEW_VERSION}"
        local awk_with_target='/## Changelog/ { print; print ""; print heading; next } 1'
    else
        echo_info "wp.org txt search-replace"
        local new_heading="= ${NEW_VERSION} ="
        local awk_with_target='/== Changelog ==/ { print; print ""; print heading; next } 1'
    fi

    awk -v heading="$new_heading" "$awk_with_target" "$FILE_PATH" > tmp.md
    mv tmp.md "$FILE_PATH"

    sed -i.tmp -e "s/Stable tag: ${OLD_VERSION}/Stable tag: ${NEW_VERSION}/g" "$FILE_PATH" && rm "$FILE_PATH.tmp"

    git add "$FILE_PATH"
}