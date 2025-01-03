#!/bin/bash
[ -n "$BASH" ] 1>/dev/null 2>&1 || {
echo "Run it in bash." 2>/dev/null; exit 1; }
THIS="${BASH_SOURCE##*/}"
CDIR=$([ -n "${BASH_SOURCE%/*}" ] && cd "${BASH_SOURCE%/*}" &>/dev/null; pwd)
# Name
THIS="${THIS:-update.sh}"
BASE="${THIS%.*}"
# Prohibits overwriting by redirect and use of undefined variables.
set -Cu
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
WITHCONFIG=
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
dotgitbase=""
dotgit_url=""
dotgitwdir="${TMPDIR:-/tmp}/.${DOTGIT_PRJ}.$$"
dotgittemp=""
dotgitdiff=""
dotgitbkup=""
dotgit_out=""
# Abort
_abort() {
  local exitcode=1 &>/dev/null
  [[ ${1:-} =~ ^[0-9]+$ ]] && {
    exitcode="${1:-}"; shift;
  } &>/dev/null
  echo "${DOTGIT_PRJ}/${THIS}: ERROR: $@" "(${exitcode:-1})" 1>&2
  [ ${exitcode:-1} -le 0 ] || exit ${exitcode:-1}
  return 0
}
# Cleanup
_cleanup() {
  [ -z "${dotgitwdir:-}" ] || {
    rm -rf "${dotgitwdir:-}" &>/dev/null
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
    git_user="$(id -un 2>/dev/null)"
    [ -n "${gitemail}" ] ||
    gitemail="$(id -un 2>/dev/null)@$(hostname -f 2>/dev/null)"
    git_conf="${filepath%.*}.global"
    echo "${filepath}" |
    egrep '^'"${HOME}" &>/dev/null && {
      git_conf="~${git_conf##*$HOME}"
    } || :
    cat "${filepath}" |
    sed -r \
      -e 's/GIT_USER_NAME/'"${git_user}"'/g' \
      -e 's/GIT_USER_EMAIL/'"${gitemail}"'/g' \
      -e 's;GIT_CONFIG_PATH;'"${git_conf}"';g' \
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
cat - <<_USAGE_
Usage: ${DOTGIT_PRJ}/${THIS}: [--global|--project|--local] [--with-config|--without-config]

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
# Enable trace, verbose
[ ${X_TRACE_ON} -eq 0 ] || {
  PS4='>(${DOTGIT_PRJ}/${THIS}:${LINENO:--})${FUNCNAME:+:$FUNCNAME()}: '
  export PS4
  set -xv
}
# File get command
dgcmd_fget=""
[ -z "${dgcmd_fget}" -a -n "$(type -P curl 2>/dev/null)" ] &&
dgcmd_fget="$(type -P curl) -sL" || :
[ -z "${dgcmd_fget}" -a -n "$(type -P wget 2>/dev/null)" ] &&
dgcmd_fget="$(type -P wget) -qO -" || :
[ -z "${dgcmd_fget}" ] && {
  _anort 1 "Command (curl or wget) not found."
} || :
# Diff command
dgcmd_diff=""
[ -z "${dgcmd_diff}" -a -n "$(type -P diff 2>/dev/null)" ] &&
dgcmd_diff="$(type -P diff 2>/dev/null)" || :
[ -z "${dgcmd_diff}" ] && {
  _abort 1 "Command (diff) not found."
} || :
# Xargs command
dgcmdxargs=""
[ -z "${dgcmdxargs}" -a -n "$(type -P xargs 2>/dev/null)" ] &&
dgcmdxargs="$(type -P xargs 2>/dev/null)" || :
# Apply to
case "${GITAPLY_TO}" in
1)
  if [ -n "${GITAPLYDIR}" ]
  then :
  elif [ ! -d "${XDG_CONFIG_HOME:-${HOME}/.config}" ]
  then GITAPLYDIR="${HOME}"
  else GITAPLYDIR="${XDG_CONFIG_HOME:-${HOME}/.config}/git"
  fi
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
  elif [ -n "${GITAPLYDIR}" -a \
         -z "${GITAPLYDIR##*.git}" -a \
         -f "${GITAPLYDIR}/config" -a \
         -d "${GITAPLYDIR}/objects" -a \
         -d "${GITAPLYDIR}/refs" ]
  then
    GITAPLY_TO=3
    GITAPLYDIR="${GITAPLYDIR}/info"
  else
    GITAPLY_TO=1
    if [ -d "${XDG_CONFIG_HOME:-$HOME/.config}" ]
    then
      GITAPLYDIR="${XDG_CONFIG_HOME:-$HOME/.config}/git"
    else
      GITAPLYDIR="${HOME}"
    fi
  fi
  ;;
esac
# with-config
if [ -z "${WITHCONFIG:-}" -a "$(pwd)" = "${HOME}" ]
then
  WITHCONFIG=1
fi
# Create a work-dir if not exists
[ -d "${dotgitwdir}" ] || {
  mkdir -p "${dotgitwdir}" &>/dev/null
} || :
# dot-git-files URL base
[ -n "${CDIR}" -a -d "${CDIR}/.git" ] &&
( cd "${CDIR}" &&
  git config --get remote.origin.url |
  egrep '/dot-git-files[.]git$'; ) &>/dev/null &&
  dotgitbase="file://${CDIR}" || :
[ -n "${dotgitbase:-}" ] ||
  dotgitbase="${DOTGIT_URL}"
# Set trap
trap "_cleanup" SIGTERM SIGHUP SIGINT SIGQUIT
trap "_cleanup" EXIT
# Mkdir: 1:${HOME}/.config/git, 3:./git/info
case "${GITAPLY_TO}" in
1|3)
  if [ ! -d "${GITAPLYDIR}" ]
  then mkdir -p "${GITAPLYDIR}"
  fi &>/dev/null
  ;;
*)
  ;;
esac
# Process files
for dotgitfile in $(
  if [ ${WITHCONFIG:-0} -ne 0 -a ${GITAPLY_TO} -le 1 ]
  then
cat - <<'_LIST_'
gitconfig.global:-
gitconfig.tmplt:-
_LIST_
  fi || :
cat - <<'_LIST_'
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

  dotgit_url="${dotgitbase}/${dotgitfile}"
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
    3::*.git/info/*ignore)
      dotgitdest="${GITAPLYDIR}/exclude"
      ;;
    3::*.git/info/*.sh)
      dotgitdest=""
      ;;
    [01]::*/.config/git/*.sh)
      dotgitdest="${GITAPLYDIR}/${dotgitfile}"
      ;;
    [01]::*/.config/git/git*|3::*.git/info/git*)
      dotgitdest="${GITAPLYDIR}/${dotgitfile#*git}"
      ;;
    [01]::*/.config/git/*)
      dotgitdest="${GITAPLYDIR}/${dotgitfile}"
      ;;
    *)
      dotgitdest="${GITAPLYDIR}/.${dotgitfile}"
      ;;
    esac

  fi # if [ -z "${dotgitdest}" ]

  [ -z "${dotgitdest}" ] ||
  case "${dotgitfile}" in
  *.sh)
    if [ -e "${GITAPLYDIR}/${dotgitfile}" -a \
       ! -e "${GITAPLYDIR}/.${dotgitfile}" ]
    then
      echo "${DOTGIT_PRJ}/${THIS}: Found '${dotgitfile}', Skip update."
      dotgit_url=""
      dotgitdest=""
    fi
    ;;
  *)
    ;;
  esac

  [ -n "${dotgitfile}" ] || continue
  [ -n "${dotgit_url}" ] || continue
  [ -n "${dotgittemp}" ] || continue
  [ -n "${dotgitdest}" ] || continue

  ${dgcmd_fget} "${dotgit_url}" 1>|"${dotgittemp}" 2>/dev/null || {
    rm -f "${dotgittemp}" &>/dev/null
    continue
  }

  case "${dotgitfile}" in
  gitattributes|gitignore)
    # *.proj
    if [ "${GITAPLY_TO}" = "2" -a -f "${dotgitdest}.proj" ]
    then additlines=$(cat "${dotgitdest}.proj" |wc -l)
    else additlines=0
    fi &>/dev/null
    if [ ${additlines:-0} -gt 0 ]
    then
      echo "${DOTGIT_PRJ}/${THIS}: Found '${dotgitdest}.proj', ${additlines} lines." && {
cat - <<_EOD_

#
# ${dotgitdest##*/}.proj
#

_EOD_
cat "${dotgitdest}.proj" 2>/dev/null
cat - <<_EOD_

_EOD_
      } 1>>"${dotgittemp}"
    else :
    fi
    # *.d/*.conf
    if [ -d "${dotgitdest}.d" ]
    then additlines=$(cat "${dotgitdest}.d"/*.conf |wc -l)
    else additlines=0
    fi &>/dev/null
    if [ ${additlines:-0} -gt 0 ]
    then
      echo "${DOTGIT_PRJ}/${THIS}: Found '${dotgitdest}.d', ${additlines} lines." && {
cat - <<_EOD_

#
# ${dotgitdest##*/}.d
#

_EOD_
cat "${dotgitdest}.d"/*.conf 2>/dev/null
cat - <<_EOD_

_EOD_
      } 1>>"${dotgittemp}"
    else :
    fi
    ;;
  *)
    ;;
  esac # case "${dotgitfile}" in

  if [ ! -s "${dotgittemp}" ]
  then
    continue
  fi

  if [ -e "${dotgitdest}" ]
  then
    ${dgcmd_diff} -u "${dotgittemp}" "${dotgitdest}" 1>|"${dotgitdiff}" && {
      echo "${DOTGIT_PRJ}/${THIS}: Same '${dotgittemp##*/}' and '${dotgitdest}'."
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
    echo "${DOTGIT_PRJ}/${THIS}: Update '${dotgitdest}'." && {

      if [ -n "${dotgitbkup}" -a -s "${dotgitbkup}" ]
      then dotgit_out="${dotgitbkup}"
      else dotgit_out="${dotgitdest}"
      fi || :

    }

  else

    : && {
      [ -n "${dotgitdest}" ] &&
      echo "${DOTGIT_PRJ}/${THIS}: Copy from '${dotgittemp}' to '${dotgitdest}'."
      [ -s "${dotgitdiff}" ] &&
      echo "${DOTGIT_PRJ}/${THIS}: Copy from '${dotgitdiff}' to '${dotgitbkup}'."
    } || :

    if [ -n "${dotgitdiff}" -a -s "${dotgitdiff}" ]
    then dotgit_out="${dotgitdiff}"
    else dotgit_out="${dotgittemp}"
    fi || :

  fi || continue

  dotgitline=$(cat "${dotgit_out}" 2>/dev/null |wc -l)

  : "Diff" && {

    echo "${dotgit_out##*/} >>>"

    cat -n "${dotgit_out}" |
    if [ ${dotgitline} -gt 10 ]
    then head -n 9; printf "%s\t\t%s" ":" ":"; echo
    else cat
    fi || :

    echo

  } |
  if [ -x "${dgcmdxargs:-}" ]
  then ${dgcmdxargs} -L1 -IR echo "${DOTGIT_PRJ}/${THIS}: R"
  else cat -
  fi

done
# Make gitconfig
if [ ${WITHCONFIG:-0} -ne 0 -a ${GITAPLY_TO} -le 1 ]
then

  gitcfgfile=""

  case "${GITAPLYDIR}" in
  */.config/git)
    gitcfgfile="${GITAPLYDIR}/config"
    ;;
  *)
    gitcfgfile="${GITAPLYDIR}/.gitconfig"
    ;;
  esac

  if [ ! -e "${gitcfgfile}" ]
  then

    for cfgtmplt in "${GITAPLYDIR}/"{,.git}config.tmplt
    do
      if [ -e "${cfgtmplt}" ]
      then
        : && {
cat - <<_EOF_
*
* The with-config option was specified.
* Generate a config file '${gitcfgfile}'.
* Use template file '${cfgtmplt}'.
*
_EOF_
          _git_config_template "${cfgtmplt}" |
          tee "${gitcfgfile}" |cat -n
          echo
        } |
        if [ -x "${dgcmdxargs:-}" ]
        then ${dgcmdxargs} -L1 -IR echo "${DOTGIT_PRJ}/${THIS}: R"
        else cat -
        fi &&
        break
      else :
      fi
    done

  fi # if [ ! -e "${gitcfgfile}" ]

else :
fi # if [ ${WITHCONFIG} -ne 0 -a ${GITAPLY_TO} -le 1 ]
# End
exit 0
