#!/bin/bash
# shellcheck disable=SC2015,SC2034,SC2086
[ -n "$BASH" ] 1>/dev/null 2>&1 || {
echo "Run it in bash." 1>&2; exit 1; }
THIS="${BASH_SOURCE:-./gitfilesupdate.sh}"
NAME="${THIS##*/}"
BASE="${NAME%.*}"
CDIR=$([ -n "${THIS%/*}" ] && cd "${THIS%/*}" &>/dev/null || :; pwd)
# Prohibits overwriting by redirect and use of undefined variables.
set -Cu
# The return value of a pipeline is the value of the last command to
# exit with a non-zero status.
set -o pipefail
# Shell opts
shellopts="-s --"
[ -n "${SHELLOPTS:-}" ] &&
[[ ${SHELLOPTS:-} =~ (^|:)xtrace(:|$) ]] &&
shellopts="-x ${shellopts}"
# Script URI
scripturi="${DOT_GIT_FILES_INSTALL_SH:-}"
if [ -z "${scripturi}" ] && [ -s "${CDIR}/update.sh" ]
then scripturi="${CDIR}/update.sh"; fi
if [ -z "${scripturi}" ] && [ ! -s "${CDIR}/update.sh" ]
then
  scripturi="https://raw.githubusercontent.com"
  scripturi="${scripturi}/mtangh/dot-git-files"
  scripturi="${scripturi}/master/update.sh"
fi
# Get Command
scriptget=""
case "${scripturi:-}" in
http://*|https://*)
  if [ -z "${scriptget}" ] && [ -n "$(type -P curl 2>/dev/null)" ]
  then scriptget="$(type -P curl 2>/dev/null) -sL"; fi
  if [ -z "${scriptget}" ] && [ -n "$(type -P wget 2>/dev/null)" ]
  then scriptget="$(type -P wget 2>/dev/null) -qO -"; fi
  ;;
*)
  scriptget="cat"
  ;;
esac
# Exec
${scriptget} "${scripturi}" |exec ${BASH} ${shellopts} "$@"
# End
exit $?
