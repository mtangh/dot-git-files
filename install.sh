#!/bin/bash
THIS="${0##*/}"
CDIR=$([ -n "${0%/*}" ] && cd "${0%/*}" 2>/dev/null; pwd)

DOT_GIT_URL="${DOT_GIT_URL:-https://raw.githubusercontent.com/mtangh/dot-git-files/master}"

set -u

dotgitfile=""
dotgitckey=""
dotgitdest=""
dotgitwdir="/tmp/.$$"
git_global=0

[ -d "./.git/" ] ||
git_global=1

[ -d "$dotgitwdir" ] || {
  mkdir -p "$dotgitwdir" 1>/dev/null 2>&1
}

[ -d "$dotgitwdir" ] && {
  trap SIGTERM "rm -rf ${dotgitwdir}/ 1>/dev/null 2>&1"
  trap SIGQUIT "rm -rf ${dotgitwdir}/ 1>/dev/null 2>&1"
  trap SIGHUP  "rm -rf ${dotgitwdir}/ 1>/dev/null 2>&1"
  trap EXIT    "rm -rf ${dotgitwdir}/ 1>/dev/null 2>&1"
}

for dotgitfile in 
  gitattributes:core.attributesfile \
  gitignore:core.excludesfile
do

  dotgitckey="${dotgitfile##*:}"
  [ -n "${dotgitckey}" ] &&
  dotgitfile="${dotgitfile%:*}"

  [ $git_global -eq 0 ] &&
  dotgitdest="./.${dotgitfile}"
  [ $git_global -eq 0 ] || {
    [ -n "${dotgitckey}" ] &&
    dotgitdest=$(git config --global "${dotgitckey}")
    [ -z "${dotgitdest}" ] &&
    dotgitdest="${HOME}/.${dotgitfile}"
  }

  [ -n "$dotgitfile" ] || continue
  [ -n "$dotgitdest" ] || continue

  curl -sL "${DOT_GIT_URL}/${dotgitfile}" |
  tee "${dotgitwdir}/${dotgitfile}" |
  diff "${dotgitdest}" - 1>/dev/null 2>&1 &&
    continue

  [ -s "${dotgitwdir}/${dotgitfile}" ] &&
  cp -pf "${dotgitwdir}/${dotgitfile}" "${dotgitdest}" && {
    echo "* ${dotgitdest} >>>"
    cat -n "${dotgitwdir}/${dotgitfile}" |head -n 10
    echo "  :"
    echo
  }

done 2>/dev/null

exit 0
