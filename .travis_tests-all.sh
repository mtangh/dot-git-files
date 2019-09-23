#!/bin/bash -Cu
THIS="${BASH_SOURCE##*/}"
CDIR=$([ -n "${BASH_SOURCE%/*}" ] && cd "${BASH_SOURCE%/*}" &>/dev/null; pwd)

# Status of all teats
tests_stat=0
# Ran tests
tests_cseq=0
# Result of test case
tests_rval=0

# Run tests
for tests_sh in .travis.d/*.sh
do

  tests_cseq=$((++tests_cseq))
  xtrace_out="${tests_sh%.sh*}.xtrace.log"
  printf "#""%.s" {1..48}
  printf "\r%s " "${tests_sh##*/}"
  echo
  BASH_XTRACEFD=3 \
  bash -x "${tests_sh}" 3>"${xtrace_out}" || {
    tests_rval=$?
    echo
    echo "${tests_sh##*/}: Exit (${tests_rval:-1})."
    echo "${tests_sh##*/}: XTRACE are:"
    cat "${xtrace_out}" 2>/dev/null
    echo
    continue
  }
  echo
  echo "OK."

done &&
[ ${tests_cseq:-0} -gt 0 ] &&
[ ${tests_rval:-1} -eq 0 ]
tests_stat=$?

# End
exit ${tests_stat:-1}
