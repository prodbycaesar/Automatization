hashflag() {
    local flags="$@"

    for var in $ARGS; do
        for flag in $flags; do
            if [ "$var" = "$flags" ]; then
                echo 'true'
                return
            fi
        done
    done
    echo 'false'
}

readopt() {
    local opts="$@"

    for var in $ARGS; do
        for opt in $opts; do
            if [[ "$var" = ${opt}* ]]; then
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

check_error() {
    local msg="$*"
    if [ "${msg//ERROR/}" != "${msg}" ]; then
        echo "${msg}"
        exit 1
    fi
}