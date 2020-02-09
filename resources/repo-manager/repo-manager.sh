#!/bin/bash

# Save a few variables, we might loose them else
operating_dir="$(pwd)"

# Helper to locate the directory of this script regardless of where it is run from
get_script_dir() {
    local source="${BASH_SOURCE[0]}"

    # See https://stackoverflow.com/questions/59895/how-to-get-the-source-directory-of-a-bash-script-from-within-the-script-itself
    while [[ -h "$source" ]]; do
        local dir="$(cd -P "$(dirname "${source}") > /dev/null 2>&1 && pwd")"
        source="$(readlink "${source}")"
        [[ "${source}" != /* ]] && source="${dir}/${source}"
    done
    
    dir="$(cd -P "$(dirname "${source}")" > /dev/null 2>&1 && pwd)"
    echo "${dir}"
}

script_dir="$(get_script_dir)"

# Enable exit on command fail
set -e

cd "${operating_dir}"

# Set utility variables
repomanager_dir="${script_dir}/.repomanager"

download_repo_manager=false

if [[ ! -z "${REPOMANAGER_DOWNLOAD_COMMAND}" ]]; then
    download_command="${REPOMANAGER_DOWNLOAD_COMMAND}"
else 
    if command -v curl > /dev/null; then
        download_command="$(command -v curl) \${url} -o \${output}"
    elif command -v wget > /dev/null; then
        download_command="$(command -v wget) \${url} -O \${output}"
    else
        >&2 echo "REPOMANAGER: Couldn't find curl nor wget, please install one of those tools or"
        >&2 echo "REPOMANAGER: set REPOMANAGER_DOWNLOAD_COMMAND='/path/to/dl \${url} \${output}'"
        >&2 echo "REPOMANAGER: (don't forget to escape the variables)"
        exit 1
    fi
fi

repomanager_download() {
    if [[ $# -ne 2 ]]; then
        >&2 echo "REPOMANAGER: repomanager_download() requires exactly 2 arguments"
        >&2 echo "REPOMANAGER:      #1 - remote url"
        >&2 echo "REPOMANAGER:      #2 - local target file"
        exit 1
    fi

    url="$1"
    output="$2"
    eval "${download_command}"
    return $?
}

repomanager_get_file() {
        if [[ $# -ne 3 ]]; then
        >&2 echo "REPOMANAGER: repomanager_get_file() requires exactly 3 arguments"
        >&2 echo "REPOMANAGER:      #1 - remote url"
        >&2 echo "REPOMANAGER:      #2 - local target file"
        >&2 echo "REPOMANAGER:      #3 - 'true' | 'false' -> If true, the file is local and url is interpreted as a path"
        exit 1
    fi

    case "$3" in
        true)
            cp -r "$1" "$2"
            ;;
        
        false)
            repomanager_download "$1" "$2"
            ;;
        
        *)
            >&2 echo "REPOMANAGER: Argument 3 for repomanager_get_file() can only be 'true' or 'false'"
            ;;
    esac
}

_get_var() {
    echo "${!1}"
}

_array_contains() {
    local value="$1"
    shift
    for el in "$@"; do
        if [[ "${el}" == "${value}" ]]; then
            return 0
        fi
    done

    return 1
}

if [[ "$REPOMANAGER_RUNNING" != true ]]; then
    # Check for the sources to download
    if [[ ! -f "${script_dir}/.repomanager-remote" ]]; then
        >&2 echo "REPOMANAGER: Missing ${script_dir}/.repomanager-remote!"
        >&2 echo "REPOMANAGER: Please add the .repomanager-remote file and define the files that should be downloaded in it!"
        exit 1
    fi

    repomanager_remote() {
        if [[ -z "${_repomanager_remote_files_count}" ]]; then
            _repomanager_remote_files_count=1
            _repomanager_remote_files_unversioned=()
        else
            _repomanager_remote_files_count=$(( $_repomanager_remote_files_count + 1 ))
        fi

        if [[ $# -lt 2 ]]; then
            >&2 echo "REPOMANAGER (.repomanager-remote): repomanager_remote() needs at least two arguments:"
            >&2 echo "REPOMANAGER (.repomanager-remote):    #1 - remote url"
            >&2 echo "REPOMANAGER (.repomanager-remote):    #2 - relative path to local file in .repomanager dir"
            >&2 echo "REPOMANAGER (.repomanager-remote):    #... optional flags"
            >&2 echo "REPOMANAGER (.repomanager-remote):        local - The file is a local file, copy with cp"
            >&2 echo "REPOMANAGER (.repomanager-remote):        unversioned - This file does not get upated by the remote"
            exit 1
        fi

        # Don't allow absolute paths or paths containing ..
        if [[ "$2" == /* ]] || [[ "$2"  == *".."* ]]; then
            >&2 echo "REPOMANAGER (.repomanager-remote): repomanager_remote() does not accept files with absolute paths or paths containing ..!"
            exit 1
        fi

        declare -g "_repomanager_remote_files_${_repomanager_remote_files_count}_url"="$1"
        shift
        declare -g "_repomanager_remote_files_${_repomanager_remote_files_count}_file"="$1"
        shift
        declare -ga "_repomanager_remote_files_${_repomanager_remote_files_count}_flags"

        for flag in "$@"; do
            case "${flag}" in
                unversioned|local)
                    ;;
                *)
                    >&1 echo "REPOMANAGER (.repomanager-remote): Unknown flag ${flag}"
                    exit 1
                    ;;
            esac

            eval "_repomanager_remote_files_${_repomanager_remote_files_count}_flags+=('${flag}')"
        done

        if _array_contains unversioned "$@"; then
            _repomanager_remote_files_unversioned+=("$_repomanager_remote_files_count")
        else
            if [[ -z "${_repomanager_current_remote}" ]]; then
                >&2 echo "REPOMANAGER (.repomanager-remote): Tried to add versioned remote file without declaring a remote version first!"
                >&2 echo "REPOMANAGER (.repomanager-remote): If there is no update index for this file, add the unversioned flag!"
                exit 1
            fi

            if _array_contains local "$@"; then
                >&2 echo "REPOMANAGER (.repomanager-remote): Can't declare a remote file as local when it it is associated with a remote!"
                exit 1
            fi

            eval "_repomanager_remote_${_repomanager_remotes_count}_files+=('$_repomanager_remote_files_count')"
        fi
    }

    repomanager_remote_version() {
        if [[ -z "${_repomanager_remotes_count}" ]]; then
            _repomanager_remotes_count=1
        else
            _repomanager_remotes_count=$(( $_repomanager_remotes_count + 1 ))
        fi

        if [[ ! $# -eq 2 ]] && [[ ! $# -eq 3 ]]; then
            >&2 echo "REPOMANAGER (.repomanager-remote): repomanager_remote_version() needs two or three:"
            >&2 echo "REPOMANAGER (.repomanager-remote):    #1 - remote name"
            >&2 echo "REPOMANAGER (.repomanager-remote):    #2 - remote url"
            >&2 echo "REPOMANAGER (.repomanager-remote):   [#3]- 'local' | 'remote' -> If this is local, interpret url as path"
            exit 1
        fi

        declare -g "_repomanager_remote_${_repomanager_remotes_count}_name"="$1"
        declare -g "_repomanager_remote_${_repomanager_remotes_count}_url"="$2"
        declare -ga "_repomanager_remote_${_repomanager_remotes_count}_files"

        case "$3" in
            local)
                declare -g "_repomanager_remote_${_repomanager_remotes_count}_local"=true
                ;;
            
            remote)
                declare -g "_repomanager_remote_${_repomanager_remotes_count}_local"=false
                ;;

            *)
                echo "REPOMANAGER (.repomanager-rmote): Argument 3 for repomanager_remote_version() can only be 'local' or 'remote'"
                ;;
        esac

        _repomanager_current_remote=$_repomanager_remotes_count
    }

    source "${script_dir}/.repomanager-remote"
    if [[ -z "$_repomanager_remote_files_count" ]] || [[ "$_repomanager_remote_files_count" -lt 1 ]]; then
        >&2 echo "REPOMANAGER: .repomanager-remote is invalid, it did not set any remote files!"
        exit 1
    fi

    _get_remote_var() {
        local var_name="_repomanager_remote_$1_$2"
        echo "${!var_name}"
    }

    _get_file_var() {
        local var_name="_repomanager_remote_files_$1_$2"
        echo "${!var_name}"
    }

    mkdir -p "${repomanager_dir}/.remotes"

    if [[ ! -z "$_repomanager_remotes_count" ]] && [[ $_repomanager_remotes_count -gt 0 ]]; then
        for i in $(seq 1 $_repomanager_remotes_count); do
            name="$(_get_remote_var $i name)"
            is_local="$(_get_remote_var $i local)"
            url="$(_get_remote_var $i url)"
            files="$(_get_remote_var $i files)"

            echo "REPOMANAGER: Checking remote ${name} for updates"
            repomanager_get_file "${url}" "${repomanager_dir}/.remotes/${name}-remote-version" "${is_local}"

            if [[ ! -f "${repomanager_dir}/.remotes/${name}-remote-version" ]] ||
                [[ "$(cat "${repomanager_dir}/.remotes/${name}-remote-version")" != "$(cat "${repomanager_dir}/.remotes/${name}-local-version")" ]]
            then
                needs_update=true
            else
                needs_update=false
            fi

            for file in $files; do
                target="${repomanager_dir}/$(_get_file_var $file file)"
                mkdir -p "$(dirname "${target}")"

                file_url="$(_get_file_var $file url)"

                if [[ ! -f "${target}" ]] || [[ "${needs_update}" == true ]]; then
                    echo "REPOMANAGER: Updating file ${target} from remote ${name} using url ${file_url}"
                    repomanager_get_file "${file_url}" "${target}" "${is_local}"
                fi
            done

            mv "${repomanager_dir}/.remotes/${name}-remote-version" "${repomanager_dir}/.remotes/${name}-local-version"
        done
    fi

    for i in "${_repomanager_remote_files_unversioned[@]}"; do
        target="${repomanager_dir}/$(_get_file_var $i file)"
        mkdir -p "$(dirname "${target}")"

        file_url="$(_get_file_var $i url)"
        flags="$(_get_file_var $i flags[@])"

        if _array_contains local ${flags[@]}; then
            is_local=true
        else
            is_local=false
        fi

        if [[ ! -f "${target}" ]]; then
            echo "REPOMANAGER: Updating unversioned file ${target} using url ${file_url}"
            repomanager_get_file "${file_url}" "${target}" "${is_local}"
        fi
    done
fi

if [[ -z "${_repomanager_in_sourced_script}" ]]; then
    if [[ -d "${repomanager_dir}/lib" ]]; then
        for file in "${repomanager_dir}/lib"/*.sh; do
            source "${repomanager_dir}/lib/${file}"
        done
    fi

    _repomanager_in_sourced_script=true
fi

echo_help() {
    if [[ ! -d "${repomanager_dir}/cmd" ]]; then
        echo "No commands installed!"
        exit 1
    fi

    if [[ "0$#" -lt 1 ]]; then
        echo "Installed commands:"
        for file in "${repomanager_dir}/cmd/"*.sh; do
            local description="$(source "${file}" "description")"
            local name="$(basename "${file}")"
            echo "- ${name%.sh} => ${description}"
        done
    else
        if [[ ! -f "${repomanager_dir}/cmd/$1.sh" ]]; then
            >&2 echo "Command $1 not found!"
            exit 1
        fi
        echo "Repomanager help for $1:"
        echo "---------------------------------------------------------"
        source "${repomanager_dir}/cmd/$1.sh" "help"
    fi
}

export REPOMANAGER_RUNNING=true

if [[ -z "$1" ]]; then
    echo_help
    exit 1
fi

cmd="$1"

if [[ "${cmd}" == /* ]] || [[ "${cmd}"  == *".."* ]]; then
    >&2 echo "REPOMANAGER: Commands can't start with / and can't contain ..!"
    exit 1
fi

shift

if [[ "${cmd}" == "help" ]]; then
    echo_help "$@"
    exit 0
fi

if [[ -f "${repomanager_dir}/cmd/${cmd}.sh" ]]; then
    source "${repomanager_dir}/cmd/${cmd}.sh" "exec" "$@"
else
    >&2 echo "REPOMANAGER: Command ${cmd} not found (as in ${repomanager_dir}/cmd/${cmd}.sh does not exist)"
    >&2 echo "REPOMANAGER: Try $0 help"
    exit 1
fi