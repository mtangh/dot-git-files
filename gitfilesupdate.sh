#!/bin/bash
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
# Script URI
scripturi="${DOT_GIT_FILES_INSTALL_SH:-}"
[ -z "${scripturi}" -a -s "${CDIR}/update.sh" ] &&
scripturi="${CDIR}/update.sh" || :
[ -z "${scripturi}" -a ! -s "${CDIR}/update.sh" ] && {
scripturi="https://raw.githubusercontent.com"
scripturi="${scripturi}/mtangh/dot-git-files"
scripturi="${scripturi}/master/update.sh"; } || :
# Shell opts
shellopts="-s --"
[ -n "${SHELLOPTS:-}" ] &&
[[ ${SHELLOPTS:-} =~ (^|:)xtrace(:|$) ]] &&
shellopts="-x ${shellopts}"
# Get Command
scriptget=""
case "${scripturi:-}" in
http://*|https://*)
  [ -z "${scriptget}" -a -n "$(type -P curl 2>/dev/null)" ] &&
  scriptget="$(type -P curl 2>/dev/null) -sL" || :
  [ -z "${scriptget}" -a  -n "$(type -P wget 2>/dev/null)" ] &&
  scriptget="$(type -P wget 2>/dev/null) -qO -" || :
  ;;
*)
  scriptget="cat"
  ;;
esac
${scriptget} "${scripturi}" |exec ${BASH} ${shellopts} "$@"
# End
exit $?
