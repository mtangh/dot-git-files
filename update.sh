#!/bin/bash
THIS="${0##*/}"
CDIR=$([ -n "${0%/*}" ] && cd "${0%/*}" 2>/dev/null; pwd)
# Name
THIS="${THIS:-update.sh}"
BASE="${THIS%.*}"

# dot-git-files URL
DOT_GIT_URL="${DOT_GIT_URL:-https://raw.githubusercontent.com/mtangh/dot-git-files/master}"

# Apply-to dir.
GITAPPLYDIR="${GIT_DIR:-}"

# Flag: Git Project (0:auto,1:global,2:project,3:local)
GITAPPLY_TO=0

# Flag: With config
WITH_CONFIG=0

# Flag: Debug
MODE_DBGRUN=0

# Flag: dry-run
MODE_DRYRUN=0

# Flag: Verbose output
VERBOSE_OUT=0

# Debug
[ "${DEBUG:-NO}" != "NO" ] && {
  MODE_DBGRUN=1
  MODE_DRYRUN=1
  VERBOSE_OUT=1
} || :

# Variables
dotgitfile=""
dotgitckey=""
dotgitdest=""
dotgit_url=""
dotgitwdir="${TMPDIR:-/tmp}/.dot-git-files.$$"
dotgittemp=""
dotgitdiff=""
dotgitbkup=""
dotgit_out=""

# Verbose
_verbose() {
  [ $VERBOSE_OUT -ne 0 ] && {
    echo "${BASE}: $@"; }
  return 0
}

_cleanup() {
  _verbose "cleanup."
  [ -z "${dotgitwdir}" ] && {
    rm -rf "${dotgitwdir}" 1>/dev/null 2>&1 &&
    _verbose "removed: '${dotgitwdir}'."
  } || :
  return 0
}

# Parsing command line options
while [ $# -gt 0 ]
do
  case "$1" in
  -g|--global)
    GITAPPLY_TO=1
    ;;
  -p|--project|--proj)
    GITAPPLY_TO=2
    ;;
  -u|--local|--user-only)
    GITAPPLY_TO=3
    ;;
  -c|--with-config)
    WITH_CONFIG=1
    ;;
  -C|--without-config)
    WITH_CONFIG=0
    ;;
  -D*|--debug*)
    MODE_DBGRUN=1
    ;;
  -d*|--dry-run*)
    MODE_DRYRUN=1
    ;;
  -*)
    echo "$THIS: ERROE: Illegal option '${1}'." 1>&2
    exit 1
    ;;
  *)
    ;;
  esac
  shift
done

# Prohibits overwriting by redirect and use of undefined variables.
set -Cu

# Enable trace, verbose
[ $MODE_DBGRUN -eq 0 ] || {
  PS4='>(${BASH_SOURCE:-$THIS}:${LINENO:-0})${FUNCNAME:+:$FUNCNAME()}: '
  export PS4
  set -xv
}

# Verbose output
[ $MODE_DRYRUN -ne 0 ] && {
  VERBOSE_OUT=1
} || :

# File get command
dgcmd_fget=""
[ -z "${dgcmd_fget}" ] &&
[ -n "$(type -P curl 2>/dev/null)" ] &&
dgcmd_fget="$(type -P curl) -sL"
[ -z "${dgcmd_fget}" ] &&
[ -n "$(type -P wget 2>/dev/null)" ] &&
dgcmd_fget="$(type -P wget) -qO -"
[ -z "${dgcmd_fget}" ] && {
  echo "$THIS: ERROR: Command (curl or wget) not found." 1>&2
  exit 1
}

# Diff command
dgcmd_diff=""
[ -z "${dgcmd_diff}" ] &&
[ -n "$(type -P diff 2>/dev/null)" ] &&
dgcmd_diff="$(type -P diff 2>/dev/null)"
[ -z "${dgcmd_diff}" ] && {
  echo "$THIS: ERROR: Command (diff) not found." 1>&2
  exit 1
}

# Apply to
case "${GITAPPLY_TO}" in
1)
  [ -n "${GITAPPLYDIR}" ] ||
  GITAPPLYDIR="${XDG_CONFIG_HOME:-$HOME/.config}/git"
  [ -d "${GITAPPLYDIR}" ] ||
  GITAPPLYDIR="${HOME}"
  ;;
2)
  [ -n "${GITAPPLYDIR}"  ] ||
  GITAPPLYDIR="$(pwd)"
  if [ -n "${GITAPPLYDIR}" -a -d "${GITAPPLYDIR}/.git" ]
  then
    GITAPPLYDIR="${GITAPPLYDIR}/.git"
  else
    echo "$THIS: ERROR: '.git' no such directory in '${GITAPPLYDIR}'." 1>&2
    exit 1
  fi || :
  ;;
3)
  [ -n "${GITAPPLYDIR}"  ] ||
  GITAPPLYDIR="$(pwd)"
  if [ -n "${GITAPPLYDIR}" -a -d "${GITAPPLYDIR}/.git/info" ]
  then
    GITAPPLYDIR="${GITAPPLYDIR}/.git/info"
  else
    echo "$THIS: ERROR: '.git/info' no such directory in '${GITAPPLYDIR}'." 1>&2
    exit 1
  fi || :
  ;;
*)
  if [ -n "${GITAPPLYDIR}"  ]
  then
    GITAPPLYDIR="$(pwd)"
  fi
  if [ -n "${GITAPPLYDIR}" -a -d "${GITAPPLYDIR}/.git" ]
  then
    GITAPPLY_TO=2
  elif [ -n "${GITAPPLYDIR}" -a -d "${GITAPPLYDIR}/.config/git" ]
  then
    GITAPPLYDIR="${GITAPPLYDIR}/.config/git"
    GITAPPLY_TO=1
  elif [ -d "${XDG_CONFIG_HOME:-$HOME/.config}/git" ]
  then
    GITAPPLYDIR="${XDG_CONFIG_HOME:-$HOME/.config}/git"
    GITAPPLY_TO=1
  else
    GITAPPLYDIR="${HOME}"
    GITAPPLY_TO=1
  fi
  ;;
esac

# Create a work-dir if not exists
[ -d "$dotgitwdir" ] || {
  mkdir -p "$dotgitwdir"
} 1>/dev/null 2>&1 || :

# Set trap
[ -d "${dotgitwdir}" ] && {
  trap "_cleanup" SIGTERM SIGHUP SIGINT SIGQUIT
  trap "_cleanup" EXIT
}

# Process files
for dotgitfile in $(
  [ $WITH_CONFIG -ne 0 -a $GITAPPLY_TO -le 1 ] && {
    cat <<_LIST_
gitconfig:-
gitconfig.local.tmplt:-
_LIST_
  } || :
  cat <<_LIST_
gitattributes:core.attributesfile
gitignore:core.excludesfile
gitkeep.sh:-
gitupdatefiles.sh:-
_LIST_
)
do

  dotgitfike=""
  dotgitckey=""

  [ -n "${dotgitfile}" ] &&
  dotgitckey="${dotgitfile#*:}"
  [ -n "${dotgitckey}" ] &&
  dotgitfile="${dotgitfile%%:*}"

  dotgit_url="${DOT_GIT_URL}/${dotgitfile}"
  dotgittemp="${dotgitwdir}/${dotgitfile}"
  dotgitdiff="${dotgitwdir}/${dotgitfile}.patch"
  dotgitbkup=""
  dotgit_out=""

  dotgitdest=""
  
  if [ $GITAPPLY_TO -ne 2 ] &&
     [ -n "${dotgitckey}" -a "${dotgitckey}" != "-" ]
  then

    if [ $GITAPPLY_TO -eq 3 ]
    then dotgitckey="--local ${dotgitckey}"
    else dotgitckey="--global ${dotgitckey}"
    fi

    eval "dotgitdest=$(git config ${dotgitckey})"

  fi # if [ $GITAPPLY_TO -ne 2 ] && ...

  if [ -z "${dotgitdest}" ]
  then

    dotgitdest="${GITAPPLYDIR}/${dotgitfile}"

    case "${GITAPPLY_TO}::${dotgitdest}" in
    [01]::*/.config/git/*.sh)
      dotgitdest="${GITAPPLYDIR}/${dotgitfile}"
      ;;
    [3]::*/.git/info/*.sh)
      dotgitdest=""
      ;;
    [3]::*/.git/info/*ignore)
      dotgitdest="${GITAPPLYDIR}/excludes"
      ;;
    [013]::*/{.config/git,.git/info}/git*)
      dotgitdest="${GITAPPLYDIR}/${dotgitfile#*git}"
      ;;
    [013]::*/{.config/git,.git/info}/*)
      dotgitdest="${GITAPPLYDIR}/${dotgitfile}"
      ;;
    *)
      dotgitdest="${GITAPPLYDIR}/.${dotgitfile}"
      ;;
    esac

  fi # if [ -z "${dotgitdest}" ]

  [ -n "$dotgitfile" ] || continue
  [ -n "$dotgit_url" ] || continue
  [ -n "$dotgittemp" ] || continue
  [ -n "$dotgitdest" ] || continue

  ${dgcmd_fget} "${dotgit_url}" 1>|"${dotgittemp}"

  additlines=$(
    : && {
      [ -d "${dotgitdest}.d" ] && {
        cat "${dotgitdest}.d"/*.conf
      }
    } |wc -l; )

  [ ${additlines:-0} -gt 0 ] && {
    [ -d "${dotgitdest}.d" ] && {
      cat <<_EOC_

#
# ${dotgitdest}.d
#

_EOC_
      cat "${dotgitdest}.d"/*.conf
      cat <<_EOC_

# End of '${dotgitdest}.d'
_EOC_
    }
  } 1>>"${dotgittemp}" || :

  if [ ! -s "${dotgittemp}" ]
  then
    continue
  fi

  if [ -e "${dotgitdest}" ]
  then
    ${dgcmd_diff} -u \
    "${dotgittemp}" "${dotgitdest}" 1>|"${dotgitdiff}" && {
      _verbose "Same '${dotgittemp}' and '${dotgitdest}'."
      continue
    }
  fi

  [ -n "${dotgitdiff}" -a -s "${dotgitdiff}" ] && {
    dotgitbkup="${dotgitdest}-$(date +'%Y%m%dT%H%M%S').patch"
  }

  if [ $MODE_DRYRUN -eq 0 ]
  then
    cat "${dotgittemp}" 1>|"${dotgitdest}" && {
      [ -s "${dotgitdiff}" ] && {
      cat "${dotgitdiff}" 1>|"${dotgitbkup}" || :; }
    } &&
    _verbose "Update '${dotgitdest}'."
  else
    : && {
      _verbose "Copy from '${dotgittemp}' to '${dotgitdest}'."
      [ -s "${dotgitdiff}" ] &&
      _verbose "Copy from '${dotgitdiff}' to '${dotgitbkup}'."
    } || :
  fi || continue

  if [ -n "${dotgitbkup}" -a -s "${dotgitbkup}" ]
  then dotgit_out="${dotgitbkup}"
  else dotgit_out="${dotgitdest}"
  fi || :

  if [ $MODE_DRYRUN -ne 0 ]
  then
    [ -n "${dotgitdiff}" -a -s "${dotgitdiff}" ] &&
    dotgit_out="${dotgitdiff}" ||
    dotgit_out="${dotgittemp}"
  fi || :
  
  echo "${dotgit_out##*/} >>>"

  dotgitline=$(cat "${dotgit_out}" |wc -l)

  cat -n "${dotgit_out}" |
  if [ $dotgitline -gt 10 ]
  then head -n 9; printf "%7s" ":"; echo
  else cat
  fi || :

  echo

done 2>|/dev/null

# End
exit 0
