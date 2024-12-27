#!/bin/bash -Cu
THIS="${BASH_SOURCE##*/}"
CDIR=$([ -n "${BASH_SOURCE%/*}" ] && cd "${BASH_SOURCE%/*}" &>/dev/null; pwd)

# Status of all tests
tests_stat=0
# Ran tests
tests_cseq=0
# Result of test case
tests_rval=0

# Tests Dir.
rm -rf "${CDIR}/t" 2>/dev/null || :
mkdir -p "${CDIR}/t" 2>/dev/null || :

# Run tests
for tests_sh in "${CDIR}"/.tests.d/*.sh
do

  tests_cseq=$((++tests_cseq))
  tests_name="${tests_sh##*/}"
  tests_name="${tests_name%.sh*}"
  xtrace_out="${tests_name}.xtrace.log"
  echo "[${tests_name}] Start the test."
  mkdir -p "${CDIR}/t/${tests_name}" &>/dev/null || :
  ( cd "${CDIR}/t/${tests_name}" && {
    BASH_XTRACEFD=3 \
    tests_name="${tests_name}" \
    tests_cdir="${CDIR}" \
    tests_wdir="${CDIR}/t/${tests_name}" \
    bash -x "${tests_sh}" 3>"${xtrace_out}" 2>&3
   }; ) || {
    tests_rval=$?
    echo
    echo "[${tests_name}] This test failed."
    echo "[${tests_name}] XTRACE is as follows:"
    cat "${xtrace_out}" 2>/dev/null
    echo
    echo "[${tests_name}] Exit with (${tests_rval:-1})."
    echo
    continue
  }
  echo
  echo "[${tests_name}] OK."

done &&
[ ${tests_cseq:-0} -gt 0 ] &&
[ ${tests_rval:-1} -eq 0 ]
tests_stat=$?

# End
exit ${tests_stat:-1}
