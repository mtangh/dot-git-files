#!/bin/bash
THIS="${0##*/}"
CDIR=$([ -n "${0%/*}" ] && cd "${0%/*}" 2>/dev/null; pwd)
# Name
THIS="${THIS:-gitupdatefiles.sh}"
BASE="${BASE}"
# Prohibits overwriting by redirect and use of undefined variables.
set -Cu
# Update Shell
update_sh="https://raw.githubusercontent.com/mtangh/dot-git-files/master/update.sh"
# Get Command
script_get=""
[ -z "${script_get}" ] &&
[ -n "$(type -P curl 2>/dev/null)" ] &&
script_get="$(type -P curl 2>/dev/null) -sL"
[ -z "${script_get}" ] &&
[ -n "$(type -P wget 2>/dev/null)" ] &&
script_get="$(type -P wget 2>/dev/null) -qO -"
# Run
${script_get} "${update_sh}" 2>/dev/null |
/bin/bash -s "$@"
# End
exit $?
