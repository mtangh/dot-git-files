#!/bin/bash -Cu
THIS="${BASH_SOURCE##*/}"
CDIR="${[ -n "${BASH_SOURCE%/*}" ] && cd "${BASH_SOURCE%/*}" &>/dev/null; pwd)

# Result
tests_result=0

# Run tests
for tests_sh in .travis.d/*.sh
do
  xtrace_out="${tests_sh%.sh*}.xtrace.log"
  printf "#""%.s" {1..48}
  printf "\r%s " "${tests_sh##*/}"
  echo
  BASH_XTRACEFD=3 \
  bash -x "${tests_sh}" 3>"${xtrace_out}" || {
    tests_result=$?
    echo
    echo "${tests_sh##*/}: Exit (${tests_result:-1})."
    echo "${tests_sh##*/}: XTRACE are:"
    cat "${tests_xtrace_out}" 2>/dev/null
    echo
    continue
  }
  echo
  echo "OK."
done

# End
exit ${tests_result:-1}
