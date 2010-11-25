#!/bin/bash

COLOR_END="\033[0m"
COLOR_RED="\033[0;31m"
COLOR_GREEN="\033[0;32m"
COLOR_BLUE="\033[0;34m"
COLOR_MAGENTA="\033[0;35m"


str_endswith () { # $STRING $STR
    [[ "${1: -${#2}}" = "$2" ]]
}

str_startswith () { # $STRING $STR
    [[ "${1::${#2}}" = "$2" ]]
}

str_repeat () { # $STRING $TIMES
    local I OUT
    for (( i=0; i<$2; i++ )); do
        OUT="${OUT}${1}"
    done

    echo $OUT
}

ask_yesno () { # $MESSAGE $DEFAULT
    local ANSWER _REST
    until [[ $ANSWER = "n" || $ANSWER = "y" ]]; do
        echo -n "$1"
        read -r ANSWER _REST < /dev/tty
        ANSWER=$(echo ${ANSWER:=$2} | tr '[A-Z]' '[a-z]')
        ANSWER=${ANSWER::1}
    done
    [[ "$ANSWER" = "y" ]]
}

display_error () { # $MESSAGE
    echo -ne $COLOR_RED
    echo -n $@
    echo -e $COLOR_END
}

abs_path () { # $FILE_PATH
    local FILE_PATH=$1
    if [[ ${FILE_PATH::1} != "/" ]]; then
        FILE_PATH="$PWD/$FILE_PATH"
    fi

    echo $(cd "$FILE_PATH"; echo $PWD)
}

create_symlink () { # $LINK_SOURCE $LINK_TARGET (both absolute or relative to $PWD)
    local LINK_SOURCE="$1" LINK_TARGET="$2"
    local TARGET_DIR=$(dirname "$LINK_TARGET")

    if [[ -e "$LINK_TARGET" ]]; then
        rm -rf "$LINK_TARGET"
    fi

    if [[ ! -d "$TARGET_DIR" ]]; then
        mkdir -p "$TARGET_DIR"
    fi

    if [[ ${LINK_SOURCE::1} != "/" ]]; then # relative source. must be resolved relative to target
        local TARGET_DIR=$(abs_path "$TARGET_DIR")
        local DIRS TARGET_DIR_REL=${TARGET_DIR#"$PWD/"}
        IFS='/' read -ra DIRS <<< "$TARGET_DIR_REL"

        LINK_SOURCE="$(str_repeat ../ ${#DIRS[@]})$1"
    fi

    ln -s "$LINK_SOURCE" "$LINK_TARGET"
    echo ln -s "$LINK_SOURCE" "$LINK_TARGET"
}

git_initialize_module () { # $MOD_PATH
    git submodule init -- "$1"
}

git_uninitialize_module () { # $MOD_NAME $MOD_PATH
    rm -rf "$GIT_TOPLEVEL/$2"
    git config --remove-section  submodule."$1" 2> /dev/null
}

do_submodule () { # $NAME $PATH $URL
    local MOD_NAME=$1 MOD_PATH=$2 MOD_URL=$3
    local INITIALIZED_URL DO_INITIALIZE LINK_SOURCE

    echo

    INITIALIZED_URL=$(git config submodule."$MOD_NAME".url)
    echo -ne "Submodule ${COLOR_GREEN}${MOD_NAME}${COLOR_END} is "
    if [ $INITIALIZED_URL ]; then
        echo -e "initialized with URL ${COLOR_BLUE}$INITIALIZED_URL${COLOR_END}"
        if ask_yesno "Change to symlink? [y]es/[N]O: " "n"; then
            git_uninitialize_module "$MOD_NAME" "$MOD_PATH"
            DO_INITIALIZE=1
        fi
    elif [[ -h "$MOD_PATH" ]]; then
        echo -n "symlinked to "
        echo -ne $COLOR_BLUE
        readlink -n "$MOD_PATH"
        echo -e $COLOR_END
        if ask_yesno "Change link source or initialize submodule? [y]es/[N]o: " "n"; then
            rm "$MOD_PATH"
            DO_INITIALIZE=1
        fi
    else
        echo "not initialized"
        DO_INITIALIZE=1
    fi

    if [[ $DO_INITIALIZE ]]; then
        until [[ -d "$LINK_SOURCE" ]]; do
            if [[ "$LINK_SOURCE" ]]; then
                display_error Not a directory: $LINK_SOURCE
            fi
            echo -ne "Enter ${COLOR_MAGENTA}link source directory${COLOR_END} for ${COLOR_GREEN}${MOD_NAME}${COLOR_END} (leave blank to initialize submodule): "
            read -er LINK_SOURCE < /dev/tty

            if [[ "$LINK_SOURCE" = "" ]]; then
                break
            fi
        done

        if [ $LINK_SOURCE ]; then
            create_symlink "$LINK_SOURCE" "$MOD_PATH"
        else
            git_initialize_module "$MOD_PATH"
        fi
    fi
}

# INITIALIZATION
GIT_TOPLEVEL=`git rev-parse --show-toplevel`

if [[ ! -d "$GIT_TOPLEVEL" ]]; then
    exit 1
fi

cd "$GIT_TOPLEVEL"

echo
echo -n "Working directory is "
echo -ne $COLOR_GREEN
echo -n $GIT_TOPLEVEL
echo -e $COLOR_END

# "MAIN LOOP"
git config --file=.gitmodules -l --null | while read -d '' -r _LINE; do
    read -r _KEY _VALUE <<< $_LINE

    if str_startswith "$_KEY" "submodule."; then
        _KEY=${_KEY:10}
        if str_endswith "$_KEY" ".path"; then
            MOD_NAME=${_KEY%*.path}
            KEY=PATH
        elif str_endswith "$_KEY" ".url"; then
            MOD_NAME=${_KEY%*.url}
            KEY=URL
        else
            continue;
        fi
    fi

    if [[ "$LAST_MOD_NAME" != "$MOD_NAME" ]]; then
        MOD_PATH=
        MOD_URL=
    fi

    if [[ "$KEY" = "PATH" ]]; then
        MOD_PATH=$_VALUE
    elif [[ "$KEY" = "URL" ]]; then
        MOD_URL=$_VALUE
    fi

    if [[ "$MOD_PATH" != "" && "$MOD_URL" != "" ]]; then
        do_submodule "$MOD_NAME" "$MOD_PATH" "$MOD_URL"
    fi

    LAST_MOD_NAME="$MOD_NAME"
done && echo && git submodule update --recursive

exit
