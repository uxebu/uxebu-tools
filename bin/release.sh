#!/bin/bash
ARGS=`getopt cptr:a: $*`
usage() {
  echo "Usage: $0 [OPTIONS] VERSION DIRECTORY [DIRECTORY ...]"
  echo
  echo "OPTIONS:"
  echo "    -r DAYS      Creates a new heading in CHANGELOG for the next release."
  echo "    -t           Creates a git tag using VERSION as label."
  echo "                 Also bumps version number in package.json, if found."
  echo "    -a APPENDIX  Specifies an appendix for the git tag. Defaults to %Y%m%d of today."
  echo "    -c           Cause a git commit for CHANGELOG."
  echo "    -p           Immediately pushes to origin/master. Implies -c."
  exit 2
}

if [ $? != 0 ]; then
  usage
fi

set -- $ARGS

TODAY=$(date -j +%s)
APPENDIX="-r$(date -j -r $TODAY '+%Y%m%d')"
DO_GIT_TAG=
DO_GIT_PUSH=
DO_GIT_COMMIT=
for i; do
  case "$i"
  in
    -r)
      let NEXT_RELEASE=$TODAY+$2*60*60*24
      NEXT_RELEASE=$(date -j -r $NEXT_RELEASE "+%Y-%m-%d")
      shift; shift;;
    -a)
      if [ -n $2 ]; then
        APPENDIX="-$2"
      else
        APPENDIX=
      fi
      shift; shift;;
    -c)
      DO_GIT_COMMIT=1; shift;;
    -t)
      DO_GIT_TAG=1; shift;;
    -p)
      DO_GIT_PUSH=1; DO_GIT_COMMIT=1; shift;;
    --)
      shift; break;;
  esac
done

CURDIR=$PWD
VERSION=$1
shift

if [ -z "$VERSION" ]; then
  usage
fi

release () {
  cd "$1"

  git checkout master && git pull

  if [ $? != 0 ]; then
    echo "Failure for $1"
    exit 1
  fi

  if [ -n "$DO_GIT_TAG" ]; then
    if [ -f package.json ]; then
      npm version "$VERSION$APPENDIX" \
        --message "Bump version number to $VERSION$APPENDIX"
      git push origin master
    else
      git tag "v$VERSION$APPENDIX"
    fi

    git push origin master --tags
  fi

  if [ -n "$NEXT_RELEASE" ]; then
    CONTENTS=`cat CHANGELOG`
    echo "v$VERSION / $NEXT_RELEASE" > CHANGELOG
    echo ------------------- >> CHANGELOG
    echo >> CHANGELOG
    echo >> CHANGELOG
    echo "$CONTENTS" >> CHANGELOG
  fi

  if [ -n "$DO_GIT_COMMIT" ]; then
    git add CHANGELOG
    git commit -m 'Add heading for next release to CHANGELOG'
  fi

  if [ -n "$DO_GIT_PUSH" ]; then
    git push origin master
  fi

  cd "$CURDIR"
}

while [ 0 -lt $# ]; do
  release "$1";
  shift;
done
