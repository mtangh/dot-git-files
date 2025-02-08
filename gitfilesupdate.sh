#!/bin/bash
[ "$0" = "$BASH_SOURCE" ] 1>/dev/null 2>&1 || {
echo "Run it directory." 1>&2; exit 1; }
THIS="${BASH_SOURCE}"
NAME="${THIS##*/}"
BASE="${NAME%.*}"
CDIR=$([ -n "${THIS%/*}" ] && cd "${THIS%/*}" &>/dev/null || :; pwd)
# Prohibits overwriting by redirect and use of undefined variables.
set -Cu
# The return value of a pipeline is the value of the last command to
# exit with a non-zero status.
set -o pipefail
# Install Shell
[ -s "${CDIR}/update.sh" ] &&
installsh="${CDIR}/update.sh" || :
[ -s "${CDIR}/update.sh" ] || {
installsh="https://raw.githubusercontent.com"
installsh="${installsh}/mtangh/dot-git-files"
installsh="${installsh}/master/update.sh"; }
# Shell opts
shellopts="-s --"
[ -n "${SHELLOPTS:-}" ] &&
[[ ${SHELLOPTS:-} =~ (^|:)xtrace(:|$) ]] &&
shellopts="-x ${shellopts}"
# Get Command
scriptget=""
case "${installsh:-}" in
http*)
  [ -z "${scriptget}" -a -n "$(type -P curl 2>/dev/null)" ] &&
  scriptget="$(type -P curl 2>/dev/null) -sL" || :
  [ -z "${scriptget}" -a  -n "$(type -P wget 2>/dev/null)" ] &&
  scriptget="$(type -P wget 2>/dev/null) -qO -" || :
  ;;
*)
  scriptget="cat"
  ;;
esac
# Run
[ -n "${scriptget}" ] &&
${scriptget} "${installsh}" 2>/dev/null |/bin/bash ${shellopts} "$@"
# End
exit $?
