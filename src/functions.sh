#!/bin/bash
# no flags here, always source this file

# echo to stderr with info tag
echo_info(){
	echo  "[Info] $*" >&2
}

# echo to stderr with error tag
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
    local LC_FILE_PATH
    LC_FILE_PATH=$(echo "$FILE" | tr '[:upper:]' '[:lower:]')

    echo "Processing file '${FILE}'..."
    if [[ "$LC_FILE_PATH" == *"/package-lock.json" ]];then
        echo_info "skip package-lock [${FILE}]."
        return
    fi
    if [[  "$LC_FILE_PATH" == *"/package.json" ]]; then
        echo_info "Updating package with 'npm version'"
        npm version "${NEW_VERSION}" --no-git-tag-version
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
    else
        echo "search-and-replace with sed"
        if [[ ${NEW_VERSION} == *"-dev" ]]; then
            # if we're going TO a new dev version, don't s/r "@since" in php docs
            sed -i.tmp -e '/^\s*\* @since/!s/'"${OLD_VERSION}"'/'"${NEW_VERSION}"'/g' "$FILE" && rm "$FILE.tmp"
        else
            sed -i.tmp -e "s/${OLD_VERSION}/${NEW_VERSION}/g" "$FILE" && rm "$FILE.tmp"
        fi
    fi

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
    local LC_FILE_PATH
    LC_FILE_PATH=$(echo "$FILE_PATH" | tr '[:upper:]' '[:lower:]')

    # handle "prepare dev" one way and "draft PR" another.
    if [[ ${NEW_VERSION} == *"-dev" ]]; then
        # if we're going TO -dev, add a new changelog heading
        # Check if the file actually has a changelog section that maintains version entries
        local has_changelog_entries=false
        if [[ "$LC_FILE_PATH" == *.md ]]; then
            # Check if there are any ### version entries after ## Changelog
            if grep -A 10 "^## Changelog" "$FILE_PATH" | grep -q "^### [0-9]"; then
                has_changelog_entries=true
                local new_heading="### ${NEW_VERSION}"
                local awk_with_target='/## Changelog/ { print; print ""; print heading; next } 1'
            fi
        else
            # Check if there are any = version = entries after == Changelog ==
            if grep -A 10 "^== Changelog ==" "$FILE_PATH" | grep -q "^= [0-9]"; then
                has_changelog_entries=true
                local new_heading="= ${NEW_VERSION} ="
                local awk_with_target='/== Changelog ==/ { print; print ""; print heading; next } 1'
            fi
        fi
        
        # Only add changelog entry if the file maintains a running changelog
        if [[ "$has_changelog_entries" == true ]]; then
            awk -v heading="$new_heading" "$awk_with_target" "$FILE_PATH" > tmp.md
            mv tmp.md "$FILE_PATH"
        else
            echo_info "Skipping changelog entry addition - no running changelog detected in ${FILE_PATH}"
        fi
    else
        # if we're going FROM -dev, update the changelog.
        # TODO: do this instead/again as part of release since PR is unlikely to merge right away
        local TODAYS_DATE
        TODAYS_DATE=$(todays_date)
        if [[ "$LC_FILE_PATH" == *.md ]]; then
            echo_info "updating changelog and adding date to readme.md (${FILE})"
            sed -i -e "s/### ${OLD_VERSION}/### ${NEW_VERSION} (${TODAYS_DATE})/g" "$FILE"
        else
            echo_info "updating changelog and adding date to readme.txt"
            sed -i -e "s/= ${OLD_VERSION}/= ${NEW_VERSION} (${TODAYS_DATE})/g" "$FILE"
        fi
    fi

    # Update only the stable tag at the top of the document
    awk -v old="${OLD_VERSION}" -v new="${NEW_VERSION}" '
    {
        gsub("Stable tag: " old, "Stable tag: " new);
        gsub("\\*\\*Stable tag:\\*\\* " old, "**Stable tag:** " new);
        print;
    }' "$FILE_PATH" > "${FILE_PATH}.tmp" && mv "${FILE_PATH}.tmp" "$FILE_PATH"


}

todays_date(){
    date +"%e %B %Y" | sed -e 's/^[[:space:]]*//'
}