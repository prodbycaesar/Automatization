# searching in arguments for flags
hashflag() {
    local flags="$@"

    # scanning script arguments for flags
    for var in $ARGS; do
        # scanning command if flag is available
        for flag in $flags; do
            # with a valid flag being used return true
            if [ "$var" = "$flags" ]; then
                echo 'true'
                return
            fi
        done
    done
    echo 'false'
}

# searching in arguments for values
readopt() {
    local opts="$@"

    # scanning script arguments for values
    for var in $ARGS; do
        # scanning command if values are expected
        for opt in $opts; do
            # check if script arguments and command arguments are the same
            if [[ "$var" = ${opt}* ]]; then
                # cut away the command and '=' for returning the value only
                local value="${var//${opt}=/}"
                if [ "$value" != "$var" ]; then
                    echo $value
                    return
                fi
            fi
        done
    done
    echo ""
}

# error checking and output if error occures
check_error() {
    local msg="$*"
    
    # removes word error from string and matches the strings 
    # if string is not matching the functions has an error and returns the error message
    if [ "${msg//ERROR/}" != "${msg}" ]; then
        echo "${msg}"
        exit 1
    fi
}