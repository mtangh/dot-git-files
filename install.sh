#!/bin/bash
THIS="${0##*/}"
CDIR=$([ -n "${0%/*}" ] && cd "${0%/*}" 2>/dev/null; pwd)
# Name
THIS="${THIS:-install.sh}"
BASE="${BASE}"

# dot-git-files URL
DOT_GIT_URL="${DOT_GIT_URL:-https://raw.githubusercontent.com/mtangh/dot-git-files/master}"

# Flag: Git Project
GIT_PROJECT=0

# Flag: dry-run
MODE_DRYRUN=0
[ -n "$DEBUG" ] &&
MODE_DRYRUN=1

# Flag: Verbose output
VERBOSE_OUT=0
[ -n "$DEBUG" ] &&
VERBOSE_OUT=1

# Variables
dotgitfile=""
dotgitckey=""
dotgitdest=""
dotgitwdir="${TMPDIR:-/tmp}/.dot-git-files.$$"

# Verbose
_verbose() {
  [ $VERBOSE_OUT -ne 0 ] && {
    echo "${BASE}: $@"; }
  return 0
}

# Parsing command line options
while [ $# -gt 0 ]
do
  case "$1" in
  --dry-run*|--debug*|-d)
    MODE_DRYRUN=1
    ;;
  --local|--project|-p)
    GIT_PROJECT=1
    ;;
  *)
    ;;
  esac
  shift
done

# Prohibits overwriting by redirect and use of undefined variables.
set -Cu

# Verbose output
[ $MODE_DRYRUN -ne 0 ] &&
VERBOSE_OUT=1

# File get command
dotgitfget=""
[ -z "${dotgitfget}" ] &&
[ -n "$(type -P curl 2>/dev/null)" ] &&
dotgitfget="$(type -P curl) -sL"
[ -z "${dotgitfget}" ] &&
[ -n "$(type -P wget 2>/dev/null)" ] &&
dotgitfget="$(type -P wget) -qO -"
[ -z "${dotgitfget}" ] && {
  echo "$THIS: ERROR: Command (curl or wget) not found." 1>&2
  exit 1
}

# Diff command
dotgitdiff=""
[ -z "${dotgitdiff}" ] &&
[ -n "$(type -P diff 2>/dev/null)" ] &&
dotgitdiff="$(type -P diff 2>/dev/null)"
[ -z "${dotgitdiff}" ] && {
  echo "$THIS: ERROR: Command (diff) not found." 1>&2
  exit 1
}

# Flag: Git Gobal
git_global=0
[ $GIT_PROJECT -eq 0 ] &&
[ ! -d "./.git/" ] &&
git_global=1

# Create a work-dir if not exists
[ -d "$dotgitwdir" ] || {
  mkdir -p "$dotgitwdir" 
} 1>/dev/null 2>&1 || :

# Set trap
[ -d "$dotgitwdir" ] && {
  trap "rm -rf '${dotgitwdir}/' 1>/dev/null 2>&1" SIGTERM SIGHUP SIGINT SIGQUIT
  trap "rm -rf '${dotgitwdir}/' 1>/dev/null 2>&1" EXIT
}

# Process files
for dotgitfile in $(
cat <<_LIST_
gitattributes:core.attributesfile
gitignore:core.excludesfile
gitkeep.sh:-
git-files-update.sh:-
_LIST_
)
do

  [ -n "${dotgitfile}" ] &&
  dotgitckey="${dotgitfile#*:}"
  [ -n "${dotgitckey}" ] &&
  dotgitfile="${dotgitfile%%:*}"

  _verbose "dotgitfile=$dotgitfile"
  _verbose "dotgitckey=$dotgitckey"

  dotgit_url="${DOT_GIT_URL}/${dotgitfile}"
  dotgittemp="${dotgitwdir}/${dotgitfile}"

  _verbose "dotgit_url=$dotgit_url"
  _verbose "dotgittemp=$dotgittemp"

  [ $git_global -eq 0 ] &&
  dotgitdest="./.${dotgitfile}"
  [ $git_global -eq 0 ] || {
    [ -n "${dotgitckey}" ] &&
    [ "${dotgitckey}" != "-" ] &&
    eval "dotgitdest=$(git config --global ${dotgitckey})"
    [ -z "${dotgitdest}" ] &&
    dotgitdest="${HOME}/.${dotgitfile}"
  }

  [ -n "$dotgitfile" ] || continue
  [ -n "$dotgit_url" ] || continue
  [ -n "$dotgittemp" ] || continue
  [ -n "$dotgitdest" ] || continue

   _verbose "dotgitdest=$dotgitdest"

  ${dotgitfget} "${dotgit_url}" 1>|"${dotgittemp}" ||
    continue
  [ -s "${dotgittemp}" ] ||
    continue
  ${dotgitdiff} "${dotgittemp}" ${dotgitdest} 1>/dev/null &&
    continue
  [ $MODE_DRYRUN -eq 0 ] && {
    cat "${dotgittemp}" 1>|"${dotgitdest}"; } ||
    continue
  [ $MODE_DRYRUN -eq 0 ] || {
    _verbose "cat '${dotgittemp}' 1>|${dotgitdest}"; }

  echo "${dotgitdest} >>>"
  cat -n "${dotgitdest}" |head -n 10
  echo "      :"
  echo

done 2>/dev/null

# End
exit 0
