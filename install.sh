#!/bin/bash
THIS="${0##*/}"
CDIR=$([ -n "${0%/*}" ] && cd "${0%/*}" 2>/dev/null; pwd)

DOT_GIT_URL="${DOT_GIT_URL:-https://raw.githubusercontent.com/mtangh/dot-git-files/master}"
MODE_DRYRUN=0

[ -n "$DEBUG" ] &&
MODE_DRYRUN=1

case "$1" in
--dry-run*|--debug*|-d)
  MODE_DRYRUN=1
  ;;
*)
  ;;
esac

set -u

dotgitfile=""
dotgitckey=""
dotgitdest=""
dotgitwdir="/tmp/.dot-git-files.$$"
git_global=0

dotgitcopy="cp -pf"
[ $MODE_DRYRUN -ne 0 ] &&
dotgitcopy="echo ${dotgitcopy}"

[ -d "./.git/" ] ||
git_global=1

[ -d "$dotgitwdir" ] || {
  mkdir -p "$dotgitwdir" 1>/dev/null 2>&1
}

[ -d "$dotgitwdir" ] && {
  trap "rm -rf ${dotgitwdir}/ 1>/dev/null 2>&1" SIGTERM SIGHUP SIGINT SIGQUIT
  trap "rm -rf ${dotgitwdir}/ 1>/dev/null 2>&1" EXIT
}

for dotgitfile in \
  "gitattributes:core.attributesfile" \
  "gitignore:core.excludesfile"
do

  dotgitckey="${dotgitfile##*:}"
  [ -n "${dotgitckey}" ] &&
  dotgitfile="${dotgitfile%:*}"

  [ $MODE_DRYRUN -eq 0 ] ||
  echo "dotgitfile=$dotgitfile dotgitckey=$dotgitckey"

  [ $git_global -eq 0 ] &&
  dotgitdest="./.${dotgitfile}"
  [ $git_global -eq 0 ] || {
    [ -n "${dotgitckey}" ] &&
    eval "dotgitdest=$(git config --global ${dotgitckey})"
    [ -z "${dotgitdest}" ] &&
    dotgitdest="${HOME}/.${dotgitfile}"
  }

  [ -n "$dotgitfile" ] || continue
  [ -n "$dotgitdest" ] || continue

  [ $MODE_DRYRUN -eq 0 ] ||
  echo "dotgitdest=$dotgitdest"

  curl -sL "${DOT_GIT_URL}/${dotgitfile}" 1>"${dotgitwdir}/${dotgitfile}" ||
    continue
  [ -s "${dotgitwdir}/${dotgitfile}" ] ||
    continue
  diff -u "${dotgitwdir}/${dotgitfile}" ${dotgitdest} &&
    continue
  $dotgitcopy "${dotgitwdir}/${dotgitfile}" ${dotgitdest} ||
    continue

  echo "${dotgitdest} >>>"
  cat -n "${dotgitwdir}/${dotgitfile}" |head -n 10
  echo "      :"
  echo

done 2>/dev/null

exit 0
