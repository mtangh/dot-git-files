#!/bin/bash
[ -n "$BASH" ] 1>/dev/null 2>&1 || {
echo "Run it in bash." 2>/dev/null; exit 1; }
THIS="${0##*/}"
CDIR=$([ -n "${0%/*}" ] && cd "${0%/*}" 2>/dev/null; pwd)
# NAME
THIS="${THIS:-gitfilesupdate.sh}"
BASE="${THIS%.*}"
# Prohibits overwriting by redirect and use of undefined variables.
set -Cu
# Install Shell
installsh="https://raw.githubusercontent.com"
installsh="${installsh}/mtangh/dot-git-files"
installsh="${installsh}/master/update.sh"
# Shell opts
shellopts="-s --"
[ -n "${SHELLOPTS}" ] && [[ ${SHELLOPTS} =~ (^|:)xtrace(:|$) ]] &&
shellopts="-x ${shellopts}"
# Get Command
scriptget=""
[ -z "${scriptget}" -a -n "$(type -P curl 2>/dev/null)" ] &&
scriptget="$(type -P curl 2>/dev/null) -sL" || :
[ -z "${scriptget}" -a  -n "$(type -P wget 2>/dev/null)" ] &&
scriptget="$(type -P wget 2>/dev/null) -qO -" || :
# Run
[ -n "${scriptget}" ] &&
${scriptget} "${installsh}" 2>/dev/null |/bin/bash ${shellopts} "$@"
# End
exit $?
