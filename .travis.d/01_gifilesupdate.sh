#!/bin/bash
THIS="${BASH_SOURCE##*/}"
CDIR="${[ -n "${BASH_SOURCE%/*}" ] && cd "${BASH_SOURCE%/*}" &>/dev/null; pwd)

# Result
tests_result=0

# Run tests
: "Basic syntax check" && {

  bash -n update.sh &&
  bash -n gitfilesupdate.sh &&
  : "OK"

} &&
: "Run with --global" && {

  rm -rf "${gitconf_dir}" 1>/dev/null 2>&1 || :

  mkdir -p "${gitconf_dir}" &&
  bash -x -- ${dotgit_root}/gitfilesupdate.sh --global &&
  [   -r "${gitconf_dir}/ignore" ] &&
  [   -r "${gitconf_dir}/attributes" ] &&
  [   -x "${gitconf_dir}/gitfilesupdate.sh" ] &&
  [   -x "${gitconf_dir}/gitkeep.sh" ] &&
  [ ! -r "${gitconf_dir}/config" ] &&
  [ ! -r "${gitconf_dir}/config.local.tmplt" ] &&
  : "OK"

} &&
: "Run with --global and --with-config" && {

  rm -rf "${gitconf_dir}" 1>/dev/null 2>&1 || :

  mkdir -p "${gitconf_dir}" &&
  bash -x -- ${dotgit_root}/gitfilesupdate.sh --global --with-config &&
  [ -r "${gitconf_dir}/ignore" ] &&
  [ -r "${gitconf_dir}/attributes" ] &&
  [ -x "${gitconf_dir}/gitfilesupdate.sh" ] &&
  [ -x "${gitconf_dir}/gitkeep.sh" ] &&
  [ -r "${gitconf_dir}/config" ] &&
  [ -r "${gitconf_dir}/config.local.tmplt" ] &&
  : "OK"

} &&
: "Run with --global and --with-config (No XDG_CONFIG_HOME)" && {

  rm -rf "${gitconf_dir}" 1>/dev/null 2>&1 || :

  bash -x -- ${dotgit_root}/gitfilesupdate.sh --global --with-config &&
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
    bash -x -- ${dotgit_root}/gitfilesupdate.sh --project ) &&
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
    bash -x -- ${dotgit_root}/gitfilesupdate.sh --local ) &&
  [   -r "${HOME}/test/.git/info/excludes" ] &&
  [   -r "${HOME}/test/.git/info/attributes" ] &&
  [ ! -x "${HOME}/test/.git/info/gitfilesupdate.sh" ] &&
  [ ! -x "${HOME}/test/.git/info/gitkeep.sh" ] &&
  : "OK"

} &&
: "DONE."

# End
exit ${tests_result:-1}
