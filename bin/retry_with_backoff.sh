#!/usr/bin/env bash

set -u

retry_with_backoff() {
    local max_attempts=${1}
    local delay=${2}
    local max_time=${3}
    local attempt=1
    local output=
    local status=

    shift 3

    while [ ${attempt} -le ${max_attempts} ]; do
        output=$("${@}")
        status=${?}

        if [ ${status} -eq 0 ]; then
            break
        fi

        if [ ${attempt} -lt ${max_attempts} ]; then
            echo "Failed attempt ${attempt} of ${max_attempts}. Retrying in ${delay} s." >&2
            sleep ${delay}
        elif [ ${attempt} -eq ${max_attempts} ]; then
            echo "Failed after ${attempt} attempts." >&2
            return ${status}
        fi

        attempt=$(( ${attempt} + 1 ))
        delay=$(( ${delay} * 2 ))
        if [ ${delay} -ge ${max_time} ]; then
            delay=${max_time}
        fi
    done

    echo "${output}"
}

RETRY=5
DELAY=1
MAX_TIME=60

usage() {
    echo "Usage:" >&2
    echo "$(basename ${0}) [-h] [-r NUM] [-d NUM] [-m NUM] COMMAND" >&2
    echo "Call the given command with retries and exponential backoff." >&2
    echo "" >&2
    echo "  -r NUM  Set the number of retry attempts (default ${RETRY})." >&2
    echo "  -d NUM  Set the base number of seconds to delay (default ${DELAY})." >&2
    echo "  -m NUM  Set the maximum delay in seconds (default ${MAX_TIME})." >&2
    echo "" >&2
}

check_numeric() {
    local arg=${1}
    if [[ ! ${arg} =~ ^[0-9]+$ ]]; then
        echo "Illegal argument: ${arg}" >&2
        echo "Expected a number." >&2
        echo "" >&2
        usage
        exit 2
    fi
}

while getopts ":hr:d:m:" arg; do
    case ${arg} in
        h)
            usage
            exit 0
            ;;
        r)
            check_numeric ${OPTARG}
            RETRY=${OPTARG}
            ;;
        d)
            check_numeric ${OPTARG}
            DELAY=${OPTARG}
            ;;
        m)
            check_numeric ${OPTARG}
            MAX_TIME=${OPTARG}
            ;;
        ?)
            echo "Invalid option: -${OPTARG}" >&2
            echo "" >&2
            usage
            exit 2
            ;;
        :)
            echo "Missing argument for: -${OPTARG}" >&2
            echo "" >&2
            usage
            exit 2
            ;;
    esac
done

retry_with_backoff ${RETRY} ${DELAY} ${MAX_TIME} ${@:OPTIND}
