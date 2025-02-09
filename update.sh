#!/bin/bash
# shellcheck disable=SC2015,SC2034,SC2120,SC2124,SC2128,SC2166
[ -n "$BASH" ] 1>/dev/null 2>&1 || {
echo "Run it in bash." 1>&2; exit 1; }
THIS="${BASH_SOURCE:-./update.sh}"
NAME="${THIS##*/}"
BASE="${NAME%.*}"
CDIR=$([ -n "${THIS%/*}" ] && cd "${THIS%/*}" &>/dev/null || :; pwd)
# Prohibits overwriting by redirect and use of undefined variables.
set -Cu
# The return value of a pipeline is the value of the last command to
# exit with a non-zero status.
set -o pipefail
# Case insensitive regular expressions.
shopt -s nocasematch
# Git Project URL
GIT_PROJ_URL="${GIT_PROJ_URL:-https://raw.githubusercontent.com/mtangh/dot-git-files/master}"
# Git Project name
GIT_PROJNAME="${GIT_PROJ_URL%/master*}"
GIT_PROJNAME="${GIT_PROJNAME##*/}"
# Install Prefix
INSTALL_PREFIX="${INSTALL_PREFIX:-}"
# Install Source
INSTALL_SOURCE="${INSTALL_SOURCE:-}"
# Install Workdir
[ -n "${INSTALLWORKDIR:-}" ] ||
INSTALLWORKDIR="$(cd ${TMPDIR:-/tmp} || :;pwd)/${GIT_PROJNAME}.$$"
# Timestamp
INSTALL_TIMEST="$(date +'%Y%m%dT%H%M%S')"
# Flag: Xtrace
X_TRACE_ON=0
# Flag: dry-run
DRY_RUN_ON=0
# Function: Stdout
_stdout() {
  local ltag="${1:-$GIT_PROJNAME/$NAME}"
  local line=""
  cat - | while IFS= read -r line
  do
    [[ "${line}" =~ ^${ltag}: ]] ||
    printf "%s: " "${ltag}"; echo "${line}"
  done
  return 0
}
# Function: Echo
_echo() {
  echo "$@" |_stdout
}
# Function: Abort
_abort() {
  local exitcode=1 &>/dev/null
  local messages="$@"
  [[ ${1:-} =~ ^[0-9]+$ ]] && {
    exitcode="${1}"; shift;
  } &>/dev/null
  echo "ERROR: ${messages} (${exitcode:-1})" |_stdout 1>&2
  [ ${exitcode:-1} -le 0 ] || exit ${exitcode:-1}
  return 0
}
# Function: Cleanup
_cleanup() {
  [ -z "${INSTALLWORKDIR:-}" ] || {
    rm -rf "${INSTALLWORKDIR:-}" &>/dev/null
  } || :
  return 0
}
# Function: usage
_usage() {
cat <<_USAGE_
Usage: ${GIT_PROJNAME}/${NAME}: [--global|--project|--local] [--with-config|--without-config]

OPTIONS:

-D, --debug
  Enable debug output.
-n, --dry-run
  Dry run mode

_USAGE_
  return 0
}
# Function: Template
_git_config_template() {
  local filepath="${1:-}"
  local git_user="${GIT_USER_NAME:-}"
  local gitemail="${GIT_USER_EMAIL:-}"
  local git_conf=""
  if [ -r "${filepath}" ] &&
     [[ "${filepath}" =~ (tmpl|tmplt|template)$ ]]
  then
    : "Mute" && {
      [ -n "${git_user}" ] || git_user="$(id -un)"
      [ -n "${gitemail}" ] || gitemail="$(id -un)@$(hostname -f)"
      git_conf="${filepath%.*}.global"
      echo "${filepath}" |grep -E '^'"${HOME}" && {
        git_conf="~${git_conf##*$HOME}"; } || :
    } &>/dev/null
    cat "${filepath}" |sed -r \
      -e 's/GIT_USER_NAME/'"${git_user}"'/g' \
      -e 's/GIT_USER_EMAIL/'"${gitemail}"'/g' \
      -e 's;GIT_CONFIG_PATH;'"${git_conf}"';g' \
      2>/dev/null || :
    [ -d "${filepath}.d" ] && {
      echo; cat "${filepath}.d"/* 2>/dev/null; }
  fi || :
  return $?
}
# Git command
git_cmnd="$(type -P git)"
[ -z "${git_cmnd}" ] && {
  _abort 1 "Command (git) not found."; } || :
# File get command
fget_cmd=""
[ -z "${fget_cmd}" -a -n "$(type -P curl 2>/dev/null)" ] &&
fget_cmd="$(type -P curl) -sL" || :
[ -z "${fget_cmd}" -a -n "$(type -P wget 2>/dev/null)" ] &&
fget_cmd="$(type -P wget) -qO -" || :
[ -z "${fget_cmd}" ] && {
  _anort 1 "Command (curl or wget) not found."; } || :
# Diff command
diff_cmd="$(type -P diff)"
[ -z "${diff_cmd}" ] && {
  _abort 1 "Command (diff) not found."; } || :
# Flag: Git Project (0:auto,1:global,2:project,3:local)
GITAPLY_TO=0
# Flag: With config
WITHCONFIG=
# Debug
[[ "${DEBUG:-NO}" =~ ^([1-9][0-9]*|YES|ON|TRUE)$ ]] && {
  X_TRACE_ON=1; DRY_RUN_ON=1; } || :
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
    _usage; exit 0
    ;;
  *)
    _abort 22 "Invalid argument, argv='${1:-}'."
    ;;
  esac
  shift
done
# Enable trace, verbose
[ ${X_TRACE_ON:-0} -eq 0 ] || {
  PS4='>(${LINENO:--})${FUNCNAME+:$FUNCNAME()}: '
  export PS4; set -xv; shopt -s extdebug; }
# Set trap
: "Trap" && {
  # Set trap
  trap "_cleanup" SIGTERM SIGHUP SIGINT SIGQUIT
  trap "_cleanup" EXIT
} || :
# Print message
cat - <<_MSG_ |_stdout
#
# ${GIT_PROJNAME}/${NAME} Date=${INSTALL_TIMEST}
#
_MSG_
# Apply to
case "${GITAPLY_TO}" in
1)
  if [ -n "${INSTALL_PREFIX}" ]
  then :
  elif [ ! -d "${XDG_CONFIG_HOME:-${HOME}/.config}" ]
  then INSTALL_PREFIX="${HOME}"
  else INSTALL_PREFIX="${XDG_CONFIG_HOME:-${HOME}/.config}/git"
  fi
  ;;
2)
  if [ -z "${INSTALL_PREFIX}" ]
  then
    INSTALL_PREFIX="$(pwd)"
  fi
  if [ -z "${INSTALL_PREFIX}" -o \
     ! -f "${INSTALL_PREFIX}/.git/config" -o \
     ! -d "${INSTALL_PREFIX}/.git/objects" -o \
     ! -d "${INSTALL_PREFIX}/.git/refs" ]
  then
    _abort 2 "'.git' no such directory in '${INSTALL_PREFIX}'."
  fi || :
  ;;
3)
  if [ -z "${INSTALL_PREFIX}" ]
  then
    INSTALL_PREFIX="$(pwd)"
  fi
  if [ -n "${INSTALL_PREFIX}" -a \
       -f "${INSTALL_PREFIX}/.git/config" -a \
       -d "${INSTALL_PREFIX}/.git/objects" -a \
       -d "${INSTALL_PREFIX}/.git/refs" ]
  then
    INSTALL_PREFIX="${INSTALL_PREFIX}/.git/info"
  else
    _abort 2 "'.git' no such directory in '${INSTALL_PREFIX}'."
  fi || :
  ;;
*)
  if [ -z "${INSTALL_PREFIX}"  ]
  then
    INSTALL_PREFIX="$(pwd)"
  fi
  if [ -n "${INSTALL_PREFIX}" -a \
       -f "${INSTALL_PREFIX}/.git/config" -a \
       -d "${INSTALL_PREFIX}/.git/objects" -a \
       -d "${INSTALL_PREFIX}/.git/refs" ]
  then
    GITAPLY_TO=2
  elif [ -n "${INSTALL_PREFIX}" -a \
         -z "${INSTALL_PREFIX##*.git}" -a \
         -f "${INSTALL_PREFIX}/config" -a \
         -d "${INSTALL_PREFIX}/objects" -a \
         -d "${INSTALL_PREFIX}/refs" ]
  then
    GITAPLY_TO=3
    INSTALL_PREFIX="${INSTALL_PREFIX}/info"
  else
    GITAPLY_TO=1
    if [ -d "${XDG_CONFIG_HOME:-$HOME/.config}" ]
    then
      INSTALL_PREFIX="${XDG_CONFIG_HOME:-$HOME/.config}/git"
    else
      INSTALL_PREFIX="${HOME}"
    fi
  fi
  ;;
esac
cat - <<_MSG_ |_stdout
GITAPLY_TO=[${GITAPLY_TO}] (0:auto,1:global,2:project,3:local)
_MSG_
# dot-git-files URL base
if [ -n "${CDIR}" -a -d "${CDIR}/.git" ]
then
  ( cd "${CDIR}" &&
    "${git_cmnd}" config --get remote.origin.url |
    grep -E "/${GIT_PROJNAME}[.]git\$" &&
    "${git_cmnd}" pull; ) &>/dev/null &&
    INSTALL_SOURCE="file://${CDIR}"
fi
[ -n "${INSTALL_SOURCE:-}" ] ||
  INSTALL_SOURCE="${GIT_PROJ_URL}"
# with-config
[ -z "${WITHCONFIG:-}" -a "$(pwd)" = "${HOME}" ] &&
  WITHCONFIG=1 || WITHCONFIG=0
# Print variables
cat - <<_MSG_ |_stdout
INSTALLWORKDIR="${INSTALLWORKDIR}"
INSTALL_SOURCE="${INSTALL_SOURCE}"
INSTALL_PREFIX="${INSTALL_PREFIX}"
_MSG_
# Mkdir: 1:${HOME}/.config/git, 3:./git/info
[ ${GITAPLY_TO:-0} -eq 1 -o \
  ${GITAPLY_TO:-0} -eq 3 ] &&
[ ! -d "${INSTALL_PREFIX}" ] && {
  mkdir -p "${INSTALL_PREFIX}"; } &>/dev/null || :
# Create a work-dir if not exists
[ -d "${INSTALLWORKDIR}" ] || {
  mkdir -p "${INSTALLWORKDIR}"; } &>/dev/null || :
# Variables
dotgitfile=""
dotgitckey=""
dotgitdest=""
dotgit_url=""
dotgittemp=""
dotgitdiff=""
dotgitbkup=""
dotgit_out=""
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

  dotgit_url="${INSTALL_SOURCE}/${dotgitfile}"
  dotgittemp="${INSTALLWORKDIR}/${dotgitfile}"
  dotgitdiff="${INSTALLWORKDIR}/${dotgitfile}.patch"
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

    eval "dotgitdest=$(${git_cmnd} config ${dotgitckey})"

  fi # if [ ${GITAPLY_TO} -ne 2 ] && ...

  if [ -z "${dotgitdest}" ]
  then

    dotgitdest="${INSTALL_PREFIX}/${dotgitfile}"

    case "${GITAPLY_TO}::${dotgitdest}" in
    3::*.git/info/*ignore)
      dotgitdest="${INSTALL_PREFIX}/exclude"
      ;;
    3::*.git/info/*.sh)
      dotgitdest=""
      ;;
    [01]::*/.config/git/*.sh)
      dotgitdest="${INSTALL_PREFIX}/${dotgitfile}"
      ;;
    [01]::*/.config/git/git*|3::*.git/info/git*)
      dotgitdest="${INSTALL_PREFIX}/${dotgitfile#*git}"
      ;;
    [01]::*/.config/git/*)
      dotgitdest="${INSTALL_PREFIX}/${dotgitfile}"
      ;;
    *)
      dotgitdest="${INSTALL_PREFIX}/.${dotgitfile}"
      ;;
    esac

  fi # if [ -z "${dotgitdest}" ]

  [ -z "${dotgitdest}" ] ||
  case "${dotgitfile}" in
  *.sh)
    if [ -e "${INSTALL_PREFIX}/${dotgitfile}" -a \
       ! -e "${INSTALL_PREFIX}/.${dotgitfile}" ]
    then
      _echo "Found '${dotgitfile}', Skip update."
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

  ${fget_cmd} "${dotgit_url}" 1>|"${dotgittemp}" 2>/dev/null || {
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
      _echo "Found '${dotgitdest}.proj', ${additlines} lines." && {
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
      _echo "Found '${dotgitdest}.d', ${additlines} lines." && {
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
    ${diff_cmd} -u "${dotgittemp}" "${dotgitdest}" 1>|"${dotgitdiff}" && {
      _echo "Same '${dotgittemp##*/}' and '${dotgitdest}'."
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
        dotgitbkup="${dotgitdest}-${INSTALL_TIMEST}.patch"
        cat "${dotgitdiff}" 1>|"${dotgitbkup}"
      } || :

    } &&
    _echo "Update '${dotgitdest}'." && {

      if [ -n "${dotgitbkup}" -a -s "${dotgitbkup}" ]
      then dotgit_out="${dotgitbkup}"
      else dotgit_out="${dotgitdest}"
      fi || :

    }

  else

    : && {
      [ -n "${dotgitdest}" ] &&
      _echo "Copy from '${dotgittemp}' to '${dotgitdest}'."
      [ -s "${dotgitdiff}" ] &&
      _echo "Copy from '${dotgitdiff}' to '${dotgitbkup}'."
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

  } |_stdout

done
# Make gitconfig
if [ ${WITHCONFIG:-0} -ne 0 -a ${GITAPLY_TO} -le 1 ]
then

  gitcfgfile=""

  case "${INSTALL_PREFIX}" in
  */.config/git)
    gitcfgfile="${INSTALL_PREFIX}/config"
    ;;
  *)
    gitcfgfile="${INSTALL_PREFIX}/.gitconfig"
    ;;
  esac

  if [ ! -e "${gitcfgfile}" ]
  then

    for cfgtmplt in "${INSTALL_PREFIX}/"{,.git}config.tmplt
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
        } |_stdout &&
        break
      else :
      fi
    done

  fi # if [ ! -e "${gitcfgfile}" ]

else :
fi # if [ ${WITHCONFIG} -ne 0 -a ${GITAPLY_TO} -le 1 ]
# End
exit 0
