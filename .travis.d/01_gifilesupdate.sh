#!/bin/bash
THIS="${BASH_SOURCE##*/}"
CDIR=$([ -n "${BASH_SOURCE%/*}" ] && cd "${BASH_SOURCE%/*}" &>/dev/null; pwd)

# Tests vars
git_config_dir="${HOME}/.config/git"

# Run tests
: "Basic syntax check" && {

  bash -n update.sh &&
  bash -n gitfilesupdate.sh &&
  : "OK"

} &&
: "Run with --global" && {

  rm -rf "${git_config_dir}" 1>/dev/null 2>&1 || :

  mkdir -p "${git_config_dir}" &&
  bash -x -- ${tests_base_dir}/gitfilesupdate.sh --global &&
  [   -r "${git_config_dir}/ignore" ] &&
  [   -r "${git_config_dir}/attributes" ] &&
  [   -x "${git_config_dir}/gitfilesupdate.sh" ] &&
  [   -x "${git_config_dir}/gitkeep.sh" ] &&
  [ ! -r "${git_config_dir}/config" ] &&
  [ ! -r "${git_config_dir}/config.local.tmplt" ] &&
  : "OK"

} &&
: "Run with --global and --with-config" && {

  rm -rf "${git_config_dir}" 1>/dev/null 2>&1 || :

  mkdir -p "${git_config_dir}" &&
  bash -x -- ${tests_base_dir}/gitfilesupdate.sh --global --with-config &&
  [ -r "${git_config_dir}/ignore" ] &&
  [ -r "${git_config_dir}/attributes" ] &&
  [ -x "${git_config_dir}/gitfilesupdate.sh" ] &&
  [ -x "${git_config_dir}/gitkeep.sh" ] &&
  [ -r "${git_config_dir}/config" ] &&
  [ -r "${git_config_dir}/config.local.tmplt" ] &&
  : "OK"

} &&
: "Run with --global and --with-config (No XDG_CONFIG_HOME)" && {

  rm -rf "${git_config_dir}" 1>/dev/null 2>&1 || :

  bash -x -- ${tests_base_dir}/gitfilesupdate.sh --global --with-config &&
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
    bash -x -- ${tests_base_dir}/gitfilesupdate.sh --project ) &&
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
    bash -x -- ${tests_base_dir}/gitfilesupdate.sh --local ) &&
  [   -r "${HOME}/test/.git/info/excludes" ] &&
  [   -r "${HOME}/test/.git/info/attributes" ] &&
  [ ! -x "${HOME}/test/.git/info/gitfilesupdate.sh" ] &&
  [ ! -x "${HOME}/test/.git/info/gitkeep.sh" ] &&
  : "OK"

} &&
: "DONE."

# End
exit $?
