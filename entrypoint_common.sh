#!/bin/bash

function version() {
    echo '20220418'
}

# Simple logging procedure
function log() {
    local LOG_MESSAGE=$1
    echo "$(date +'%Y-%m-%d %H:%M:%S.%3N') - ${LOG_MESSAGE}"
}

# Simple Bash Template Rendering Procedure
# Files must escape Bash style variables if you do not want them rendered out
# Files must also not contain the letters EOF or you must update this function
function render_template() {
    local TEMPLATE_FILE=$1
    local TEMPLATE_OUTPUT=$( echo "cat <<EOF"; echo "$(cat $TEMPLATE_FILE)"; echo "EOF" )
    eval "$TEMPLATE_OUTPUT"
}

# This little function just checks to see if the file your editing ends in a newline
# and should only be used as part of the set_prop function to ensure we're adding
# newlines before appending a value
function file_ends_with_newline() {
    local FILE=$1
    if [[ -f ${FILE} ]]
    then
        [[ $(tail -c1 "${FILE}" | wc -l) -gt 0 ]]
    else
        return 0
    fi
}

# Replaces or Appends Key Value Pairs in a Java Style Properties File
function set_prop() {
    local KEY=$1
    local VALUE=$2
    local FILE=$3

    if ! grep --silent "^[#]*\s*${KEY}[ ]*=[ ]*.*" ${FILE} 2>/dev/null; then
        log "APPENDING '${KEY}'"
        if ! file_ends_with_newline ${FILE}
        then
            echo "" >> ${FILE}
        fi
        echo "${KEY}=${VALUE}" >> ${FILE}
    elif ! grep --silent "^${KEY}[ ]*=[ ]*${VALUE}$" ${FILE} 2>/dev/null; then
        log "UPDATING '${KEY}'"
        sed -i'' "s~^[#]*\s*${KEY}[ ]*=[ ]*.*~${KEY}=${VALUE}~" ${FILE}
    else
        log "SKIPPING '${KEY}'"
    fi
}

# Escape Java style properties
# See https://docs.oracle.com/javase/7/docs/api/java/util/Properties.html#load%28java.io.Reader%29 for details.
function escape_prop() {
    local VALUE=$1
    echo ${VALUE} | sed 's~\([=: ]\)~\\\\\1~g'
}

# Accepts a JSON String with file, key and value and updates a Java style properties file.
function set_custom_prop() {
    local KEY="$(jq '.key' <<< "$1")"
    local VALUE="$(jq '.value' <<< "$1")"
    local FILE="$(jq '.file' <<< "$1")"

    set_prop "${FILE}" "$(escape_prop ${KEY})" "$(escape_prop ${VALUE})"
}

# Accepts a Variable Prefix and then iterates through all variables with that prefix and applies them their
# respective configuration file using the set_custom_prop() function above. It is assumed that each variable
# will be valid JSON and the script will exit and fail if that's not the case.
function set_custom_props() {
    local PREFIX="${1}"

    for i in $(eval 'echo ${!'"${PREFIX}"'@}')
    do
        set_custom_prop "${!i}"
    done
}

# Accepts a file name and rotates it appending the date on the end of the file name.
function rotate_log() {
    local FILE=$1
    log "Started Rotating ${FILE}"
    cp ${FILE} ${FILE}.$(date +%Y-%m-%d)
    cat /dev/null > ${FILE}
    log "Finished Rotating ${FILE}"
}

function log_cleanup_loop() {
    log "Starting Log Cleanup Loop"
    local LOG_FOLDER=$1
    while true
    do
        # Delete rotated logs more than 24 hours old
        sleep 300
        log "Log Cleanup Starting"
        find ${LOG_FOLDER} -type f -mtime +0 -regextype posix-extended -regex '.*\.[0-9]{4}-[0-9]{2}-[0-9]{2}' -printf 'Removing %p\n' -exec rm {} \;
        log "Log Cleanup Finished"
    done
    log "Finished Log Cleanup Loop"
}

function log_rotate_loop() {
    log "Starting Log Rotate Loop"
    local FILES="$@"
    while true
    do
        # Rotate logs every 24 hours
        sleep 86400
        log "Started Rotating Logs"
        for FILE in "${FILES}"
        do
            rotate_log "${FILE}"
        done
        log "Finished Rotating Logs"
    done
    log "Finished Log Rotate Loop"
}