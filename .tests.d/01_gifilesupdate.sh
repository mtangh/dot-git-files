#!/bin/bash
THIS="${BASH_SOURCE##*/}"
CDIR=$([ -n "${BASH_SOURCE%/*}" ] && cd "${BASH_SOURCE%/*}" &>/dev/null; pwd)

# Tests vars
gitconfdir="${HOME}/.config/git"

# Run tests
: "Basic syntax check" && {

  bash -n update.sh &&
  bash -n gitfilesupdate.sh &&
  : "OK"

} &&
: "Run with --global" && {

  rm -rf "${gitconfdir}" 1>/dev/null 2>&1 || :

  mkdir -p "${gitconfdir}" &&
  bash -x -- ${tests_wdir}/gitfilesupdate.sh --global &&
  [   -r "${gitconfdir}/ignore" ] &&
  [   -r "${gitconfdir}/attributes" ] &&
  [   -x "${gitconfdir}/gitfilesupdate.sh" ] &&
  [   -x "${gitconfdir}/gitkeep.sh" ] &&
  [ ! -r "${gitconfdir}/config" ] &&
  [ ! -r "${gitconfdir}/config.local.tmplt" ] &&
  : "OK"

} &&
: "Run with --global and --with-config" && {

  rm -rf "${gitconfdir}" 1>/dev/null 2>&1 || :

  mkdir -p "${gitconfdir}" &&
  bash -x -- ${tests_wdir}/gitfilesupdate.sh --global --with-config &&
  [ -r "${gitconfdir}/ignore" ] &&
  [ -r "${gitconfdir}/attributes" ] &&
  [ -x "${gitconfdir}/gitfilesupdate.sh" ] &&
  [ -x "${gitconfdir}/gitkeep.sh" ] &&
  [ -r "${gitconfdir}/config" ] &&
  [ -r "${gitconfdir}/config.local.tmplt" ] &&
  : "OK"

} &&
: "Run with --global and --with-config (No XDG_CONFIG_HOME)" && {

  rm -rf "${gitconfdir}" 1>/dev/null 2>&1 || :

  bash -x -- ${tests_wdir}/gitfilesupdate.sh --global --with-config &&
  [ -r "${HOME}/.gitignore" ] &&
  [ -r "${HOME}/.gitattributes" ] &&
  [ -x "${HOME}/.gitfilesupdate.sh" ] &&
  [ -x "${HOME}/.gitkeep.sh" ] &&
  [ -r "${HOME}/.gitconfig" ] &&
  [ -r "${HOME}/.gitconfig.local.tmplt" ] &&
  : "OK"

} &&
: "Run with --project" && {

  rm -rf "${HOME}/test" 1>/dev/null 2>&1 || :

  ( git init "${HOME}/test" &&
    cd "${HOME}/test" &&
    bash -x -- ${tests_wdir}/gitfilesupdate.sh --project ) &&
  [ -r "${HOME}/test/.gitignore" ] &&
  [ -r "${HOME}/test/.gitattributes" ] &&
  [ -x "${HOME}/test/.gitfilesupdate.sh" ] &&
  [ -x "${HOME}/test/.gitkeep.sh" ] &&
  : "OK"

} &&
: "Run with --local" && {

  rm -rf "${HOME}/test" 1>/dev/null 2>&1 || :

  ( git init "${HOME}/test" &&
    cd "${HOME}/test" &&
    bash -x -- ${tests_wdir}/gitfilesupdate.sh --local ) &&
  [   -r "${HOME}/test/.git/info/excludes" ] &&
  [   -r "${HOME}/test/.git/info/attributes" ] &&
  [ ! -x "${HOME}/test/.git/info/gitfilesupdate.sh" ] &&
  [ ! -x "${HOME}/test/.git/info/gitkeep.sh" ] &&
  : "OK"

} &&
: "DONE."

# End
exit $?
