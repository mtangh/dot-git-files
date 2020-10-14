#!/bin/bash -u
THIS="${BASH_SOURCE##*/}"
CDIR=$([ -n "${BASH_SOURCE%/*}" ] && cd "${BASH_SOURCE%/*}" 2>/dev/null; pwd)

# Name
THIS="${THIS:-update.sh}"
NAME="${THIS%.*}"

# dot-git-files URL
DOTGIT_URL="${DOTGIT_URL:-https://raw.githubusercontent.com/mtangh/dot-git-files/master}"

# dot-ssh-files name
DOTGIT_PRJ="${DOTGIT_URL%/master*}"
DOTGIT_PRJ="${DOTGIT_PRJ##*/}"

# Apply-to dir.
GITAPLYDIR="${GIT_DIR:-}"

# Flag: Git Project (0:auto,1:global,2:project,3:local)
GITAPLY_TO=0

# Flag: With config
WITHCONFIG=0

# Flag: Xtrace
X_TRACE_ON=0

# Flag: dry-run
DRY_RUN_ON=0

# Debug
case "${DEBUG:-NO}" in
0|[Nn][Oo]|[Oo][Ff][Ff])
  ;;
*)
  X_TRACE_ON=1
  DRY_RUN_ON=1
  ;;
esac || :

# Variables
dotgitfile=""
dotgitckey=""
dotgitdest=""
dotgit_url=""
dotgitwdir="${TMPDIR:-/tmp}/.${DOTGIT_PRJ}.$$"
dotgittemp=""
dotgitdiff=""
dotgitbkup=""
dotgit_out=""

# Stdout
_stdout() {
  local rowlabel="${1:-$THIS}"
  local row_data=""
  cat | while IFS= read row_data
  do
    if [[ "${row_data}" =~ ^${rowlabel}: ]]
    then printf "%s" "${row_data}"
    else printf "${rowlabel}: %s" "${row_data}"
    fi; echo
  done
  return 0
}

# Abort
_abort() {
  local exitcode=1 &>/dev/null
  [[ ${1:-} =~ ^[0-9]+$ ]] && {
    exitcode="${1:-}"; shift;
  } &>/dev/null
  echo "ERROR: $@" "(${exitcode:-1})" |_stdout 1>&2
  [ ${exitcode:-1} -le 0 ] || exit ${exitcode:-1}
  return 0
}

# Cleanup
_cleanup() {
  [ -z "${dotgitwdir:-}" ] || {
    rm -rf "${dotgitwdir:-}" 1>/dev/null 2>&1
  } || :
  return 0
}

# Template
_git_config_template() {
  local filepath="${1:-}"
  local git_user="${GIT_USER_NAME:-}"
  local gitemail="${GIT_USER_EMAIL:-}"
  local git_conf=""
  [ -r "${filepath}" ] &&
  case "${filepath##*.}" in
  tmpl|tmplt|template)
    [ -n "${git_user}" ] ||
    git_user="$(uname -un 2>/dev/null)"
    [ -n "${git_user}" ] ||
    gitemail="$(uname -un 2>/dev/null)@$(hostname -f 2>/dev/null)"
    git_conf="${filepath%.*}.global"
    cat "${filepath}" |
    egrep "^${HOME}" 1>/dev/null 2>&1 && {
      git_conf="~${git_conf##*${HOME}}"
    } || :
    cat "${filepath}" |
    sed -e \
      's/GIT_USER_NAME/\1'"${git_user}"'/g' \
      's/GIT_USER_EMAIL/\1'"${gitemail}"'/g' \
      's;GIT_CONFIG_PATH;'"${git_conf}"';g' \
      2>/dev/null || :
    [ -d "${filepath}.d" ] && {
      echo
      cat "${filepath}.d"/* 2>/dev/null
    } || :
    ;;
  *)
    ;;
  esac || :
  return $?
}

# Parsing command line options
while [ $# -gt 0 ]
do
  case "${1:-}" in
  -g|--global)
    [ ${GITAPLY_TO} -eq 0 ] && {
      GITAPLY_TO=1
    }
    ;;
  -p|--project|--proj)
    [ ${GITAPLY_TO} -eq 0 ] && {
      GITAPLY_TO=2
    }
    ;;
  -u|--local|--user-only)
    [ ${GITAPLY_TO} -eq 0 ] && {
      GITAPLY_TO=3
    }
    ;;
  -c|--with-config)
    WITHCONFIG=1
    ;;
  -C|--without-config)
    WITHCONFIG=0
    ;;
  -D*|-debug*|--debug*)
    X_TRACE_ON=1
    ;;
  -n*|-dry-run*|--dry-run*)
    DRY_RUN_ON=1
    ;;
  -h|-help*|--help*)
    cat <<_USAGE_
Usage: ${THIS:-${DOTGIT_PRJ}/update.sh} [--global|--project|--local] [--with-config|--without-config]

_USAGE_
    exit 0
    ;;
  -*)
    _abort 22 "Illegal option '${1:-}'."
    ;;
  *)
    _abort 22 "Illegal argument '${1:-}'."
    ;;
  esac
  shift
done

# Redirect to filter
exec 1> >(set +x; _stdout "${DOTGIT_PRJ}/${THIS}" 2>/dev/null)

# Prohibits overwriting by redirect and use of undefined variables.
set -Cu

# Enable trace, verbose
[ ${X_TRACE_ON} -eq 0 ] || {
  PS4='>(${THIS:-${DOTGIT_PRJ}/update.sh}:${LINENO:--})${FUNCNAME:+:$FUNCNAME()}: '
  export PS4
  set -xv
}

# File get command
dgcmd_fget=""
[ -z "${dgcmd_fget}" ] &&
[ -n "$(type -P curl 2>/dev/null)" ] &&
dgcmd_fget="$(type -P curl) -sL"
[ -z "${dgcmd_fget}" ] &&
[ -n "$(type -P wget 2>/dev/null)" ] &&
dgcmd_fget="$(type -P wget) -qO -"
[ -z "${dgcmd_fget}" ] && {
  _anort 1 "Command (curl or wget) not found."
}

# Diff command
dgcmd_diff=""
[ -z "${dgcmd_diff}" ] &&
[ -n "$(type -P diff 2>/dev/null)" ] &&
dgcmd_diff="$(type -P diff 2>/dev/null)"
[ -z "${dgcmd_diff}" ] && {
  _abort 1 "Command (diff) not found."
}

# Apply to
case "${GITAPLY_TO}" in
1)
  [ -n "${GITAPLYDIR}" ] ||
  GITAPLYDIR="${XDG_CONFIG_HOME:-${HOME}/.config}/git"
  [ -d "${GITAPLYDIR}" ] ||
  GITAPLYDIR="${HOME}"
  ;;
2)
  if [ -z "${GITAPLYDIR}" ]
  then
    GITAPLYDIR="$(pwd)"
  fi
  if [ -z "${GITAPLYDIR}" -o \
     ! -f "${GITAPLYDIR}/.git/config" -o \
     ! -d "${GITAPLYDIR}/.git/objects" -o \
     ! -d "${GITAPLYDIR}/.git/refs" ]
  then
    _abort 2 "'.git' no such directory in '${GITAPLYDIR}'."
  fi || :
  ;;
3)
  if [ -z "${GITAPLYDIR}" ]
  then
    GITAPLYDIR="$(pwd)"
  fi
  if [ -n "${GITAPLYDIR}" -a \
       -f "${GITAPLYDIR}/.git/config" -a \
       -d "${GITAPLYDIR}/.git/objects" -a \
       -d "${GITAPLYDIR}/.git/refs" ]
  then
    GITAPLYDIR="${GITAPLYDIR}/.git/info"
  else
    _abort 2 "'.git' no such directory in '${GITAPLYDIR}'."
  fi || :
  ;;
*)
  if [ -z "${GITAPLYDIR}"  ]
  then
    GITAPLYDIR="$(pwd)"
  fi
  if [ -n "${GITAPLYDIR}" -a \
       -f "${GITAPLYDIR}/.git/config" -a \
       -d "${GITAPLYDIR}/.git/objects" -a \
       -d "${GITAPLYDIR}/.git/refs" ]
  then
    GITAPLY_TO=2
  elif [ -n "${GITAPLYDIR}" -a -d "${GITAPLYDIR}/.config/git" ]
  then
    GITAPLYDIR="${GITAPLYDIR}/.config/git"
    GITAPLY_TO=1
  elif [ -d "${XDG_CONFIG_HOME:-$HOME/.config}/git" ]
  then
    GITAPLYDIR="${XDG_CONFIG_HOME:-$HOME/.config}/git"
    GITAPLY_TO=1
  else
    GITAPLYDIR="${HOME}"
    GITAPLY_TO=1
  fi
  ;;
esac

# Create a work-dir if not exists
[ -d "${dotgitwdir}" ] || {
  mkdir -p "${dotgitwdir}" 1>/dev/null 2>&1
} || :

# Set trap
trap "_cleanup" SIGTERM SIGHUP SIGINT SIGQUIT
trap "_cleanup" EXIT

# git/info
if [ "${GITAPLY_TO}" = "3" -a ! -d "${GITAPLYDIR}" ]
then mkdir -p "${GITAPLYDIR}"
fi 1>/dev/null 2>&1

# Process files
for dotgitfile in $(
  if [ ${WITHCONFIG} -ne 0 -a ${GITAPLY_TO} -le 1 ]
  then
    cat <<_LIST_
gitconfig.global:-
gitconfig.tmplt:-
_LIST_
  fi || :
  cat <<_LIST_
gitattributes:core.attributesfile
gitignore:core.excludesfile
gitkeep.sh:-
gitfilesupdate.sh:-
_LIST_
)
do

  dotgitfike=""
  dotgitckey=""

  [ -n "${dotgitfile}" ] &&
  dotgitckey="${dotgitfile#*:}"
  [ -n "${dotgitckey}" ] &&
  dotgitfile="${dotgitfile%%:*}"

  dotgit_url="${DOTGIT_URL}/${dotgitfile}"
  dotgittemp="${dotgitwdir}/${dotgitfile}"
  dotgitdiff="${dotgitwdir}/${dotgitfile}.patch"
  dotgitbkup=""
  dotgit_out=""

  dotgitdest=""

  if [ ${GITAPLY_TO} -ne 2 ] &&
     [ -n "${dotgitckey}" -a "${dotgitckey}" != "-" ]
  then

    if [ ${GITAPLY_TO} -eq 3 ]
    then dotgitckey="--local ${dotgitckey}"
    else dotgitckey="--global ${dotgitckey}"
    fi

    eval "dotgitdest=$(git config ${dotgitckey})"

  fi # if [ ${GITAPLY_TO} -ne 2 ] && ...

  if [ -z "${dotgitdest}" ]
  then

    dotgitdest="${GITAPLYDIR}/${dotgitfile}"

    case "${GITAPLY_TO}::${dotgitdest}" in
    3::*/.git/info/*.sh)
      dotgitdest=""
      ;;
    3::*/.git/info/*ignore)
      dotgitdest="${GITAPLYDIR}/excludes"
      ;;
    [01]::*/.config/git/*.sh)
      dotgitdest="${GITAPLYDIR}/${dotgitfile}"
      ;;
    [01]::*/.config/git/git*|3::*/.git/info/git*)
      dotgitdest="${GITAPLYDIR}/${dotgitfile#*git}"
      ;;
    [01]::*/.config/git/*|3::*/.git/info/*)
      dotgitdest="${GITAPLYDIR}/${dotgitfile}"
      ;;
    *)
      dotgitdest="${GITAPLYDIR}/.${dotgitfile}"
      ;;
    esac

  fi # if [ -z "${dotgitdest}" ]

  [ -n "${dotgitfile}" ] || continue
  [ -n "${dotgit_url}" ] || continue
  [ -n "${dotgittemp}" ] || continue
  [ -n "${dotgitdest}" ] || continue

  ${dgcmd_fget} "${dotgit_url}" 1>|"${dotgittemp}" 2>/dev/null || {
    rm -f "${dotgittemp}" 1>/dev/null 2>&1
    continue
  }

  additlines=$(
    [ -f "${dotgitdest}.proj" ] && {
      cat "${dotgitdest}.proj"
    } 2>/dev/null |wc -l |tr -d '\t ')

  if [ ${additlines:-0} -gt 0 ]
  then

    echo "Found '${dotgitdest}.proj', ${additlines} lines."

    : && {
      cat <<_EOD_

#
# ${dotgitdest##*/}.proj
#

_EOD_
      cat "${dotgitdest}.proj" 2>/dev/null
      cat <<_EOD_

_EOD_
    } 1>>"${dotgittemp}"

  else :
  fi || :

  additlines=$(
    [ -d "${dotgitdest}.d" ] && {
      cat "${dotgitdest}.d"/*.conf
    } 2>/dev/null |wc -l |tr -d '\t ')

  if [ ${additlines:-0} -gt 0 ]
  then

    echo "Found '${dotgitdest}.d', ${additlines} lines."

    : && {
      cat <<_EOD_

#
# ${dotgitdest##*/}.d
#

_EOD_
      cat "${dotgitdest}.d"/*.conf 2>/dev/null
      cat <<_EOD_

_EOD_
    } 1>>"${dotgittemp}"

  else :
  fi || :

  if [ ! -s "${dotgittemp}" ]
  then
    continue
  fi

  if [ -e "${dotgitdest}" ]
  then
    ${dgcmd_diff} -u "${dotgittemp}" "${dotgitdest}" 1>|"${dotgitdiff}" && {
      echo "Same '${dotgittemp##*/}' and '${dotgitdest}'."
      continue
    }
  fi

  if [ ${DRY_RUN_ON} -eq 0 ]
  then

    cat "${dotgittemp}" 1>|"${dotgitdest}" && {

      case "${dotgitdest}" in
      *.sh) chmod a+x "${dotgitdest}" ;;
      *) ;;
      esac || :
      [ ${GITAPLY_TO} -le 1 -a -s "${dotgitdiff}" ] && {
        dotgitbkup="${dotgitdest}-$(date +'%Y%m%dT%H%M%S').patch"
        cat "${dotgitdiff}" 1>|"${dotgitbkup}"
      } || :

    } &&
    echo "Update '${dotgitdest}'." && {

      dotgit_out=$(
        if [ -n "${dotgitbkup}" -a -s "${dotgitbkup}" ]
        then echo "${dotgitbkup}"
        else echo "${dotgitdest}"
        fi || :; )

    }

  else

    : && {
      [ -n "${dotgitdest}" ] &&
      echo "Copy from '${dotgittemp}' to '${dotgitdest}'."
      [ -s "${dotgitdiff}" ] &&
      echo "Copy from '${dotgitdiff}' to '${dotgitbkup}'."
    } || :

    dotgit_out=$(
      if [ -n "${dotgitdiff}" -a -s "${dotgitdiff}" ]
      then echo "${dotgitdiff}"
      else echo "${dotgittemp}"
      fi || :; )

  fi || continue

  echo "${dotgit_out##*/} >>>"

  dotgitline=$(cat "${dotgit_out}" 2>/dev/null |wc -l)

  cat -n "${dotgit_out}" |
  if [ $dotgitline -gt 10 ]
  then head -n 9; printf "%7s" ":"; echo
  else cat
  fi || :

  echo

done

# Make .gitconfig
if [ ${WITHCONFIG} -ne 0 -a ${GITAPLY_TO} -le 1 ]
then
  if [ ! -e "${HOME}/.gitconfig" ]
  then
    for cfgtmplt in "${GITAPLYDIR}/"{,.git}config.tmplt
    do
      [ -e "${cfgtmplt}" ] && {
        _git_config_template "${cfgtmplt}" 1>|"${HOME}/.gitconfig" &&
        break
      } || :
    done
  fi
fi

# End
exit 0
