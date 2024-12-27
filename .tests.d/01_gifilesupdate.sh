#!/bin/bash
THIS="${BASH_SOURCE##*/}"
CDIR=$([ -n "${BASH_SOURCE%/*}" ] && cd "${BASH_SOURCE%/*}" &>/dev/null; pwd)

# Tests vars
t_home_dir=""
t_gitcfdir=""
t_work_dir=""

# Run tests
echo "[${tests_name}] Basic syntax check" && {

  bash -n ${tests_cdir}/update.sh &&
  bash -n ${tests_cdir}/gitfilesupdate.sh &&
  : "OK"

} &&
echo "[${tests_name}] Run with --global" && {

  t_home_dir="${tests_wdir}/gituser01"
  t_gitcfdir="${t_home_dir}/.config/git"

  mkdir -p "${t_gitcfdir}" &&
  ( XDG_CONFIG_HOME="${t_gitcfdir%/git}";
    export XDG_CONFIG_HOME;
    bash -x -- ${tests_cdir}/gitfilesupdate.sh --global; ) &&
  [   -r "${t_gitcfdir}/ignore" ] &&
  [   -r "${t_gitcfdir}/attributes" ] &&
  [   -x "${t_gitcfdir}/gitfilesupdate.sh" ] &&
  [   -x "${t_gitcfdir}/gitkeep.sh" ] &&
  [ ! -r "${t_gitcfdir}/config.global" ] &&
  [ ! -r "${t_gitcfdir}/config.tmplt" ] &&
  : "OK"

} &&
echo "[${tests_name}] Run with --global and --with-config" && {

  t_home_dir="${tests_wdir}/gituser02"
  t_gitcfdir="${t_home_dir}/.config/git"

  mkdir -p "${t_gitcfdir}" &&
  ( XDG_CONFIG_HOME="${t_gitcfdir%/git}"; export XDG_CONFIG_HOME;
    bash -x -- ${tests_cdir}/gitfilesupdate.sh --global --with-config; ) &&
  [ -r "${t_gitcfdir}/ignore" ] &&
  [ -r "${t_gitcfdir}/attributes" ] &&
  [ -x "${t_gitcfdir}/gitfilesupdate.sh" ] &&
  [ -x "${t_gitcfdir}/gitkeep.sh" ] &&
  [ -r "${t_gitcfdir}/config.global" ] &&
  [ -r "${t_gitcfdir}/config.tmplt" ] &&
  : "OK"

} &&
echo "[${tests_name}] Run with --global and --with-config (No XDG_CONFIG_HOME)" && {

  t_home_dir="${tests_wdir}/gituser03"
  t_gitcfdir=""

  ( unset XDG_CONFIG_HOME;
    HOME="${t_home_dir}"; export HOME;
    bash -x -- ${tests_cdir}/gitfilesupdate.sh --global --with-config; ) &&
  [ -r "${t_home_dir}/.gitignore" ] &&
  [ -r "${t_home_dir}/.gitattributes" ] &&
  [ -x "${t_home_dir}/.gitfilesupdate.sh" ] &&
  [ -x "${t_home_dir}/.gitkeep.sh" ] &&
  [ -r "${t_home_dir}/.gitconfig.global" ] &&
  [ -r "${t_home_dir}/.gitconfig.tmplt" ] &&
  : "OK"

} &&
echo "[${tests_name}] Run with --project" && {

  t_work_dir="${tests_wdir}/test-project"

  rm -rf "${t_work_dir}" 1>/dev/null 2>&1 || :

  ( git init "${t_work_dir}" && cd "${t_work_dir}/" &&
    bash -x -- ${tests_cdir}/gitfilesupdate.sh --project ) &&
  [ -r "${t_work_dir}/.gitignore" ] &&
  [ -r "${t_work_dir}/.gitattributes" ] &&
  [ -x "${t_work_dir}/.gitfilesupdate.sh" ] &&
  [ -x "${t_work_dir}/.gitkeep.sh" ] &&
  : "OK"

} &&
echo "[${tests_name}] Run with --local" && {

  t_work_dir="${tests_wdir}/test-local"

  rm -rf "${t_work_dir}" 1>/dev/null 2>&1 || :

  ( git init "${t_work_dir}" && cd "${t_work_dir}" &&
    bash -x -- ${tests_cdir}/gitfilesupdate.sh --local ) &&
  [   -r "${t_work_dir}/.git/info/exclude" ] &&
  [   -r "${t_work_dir}/.git/info/attributes" ] &&
  [ ! -x "${t_work_dir}/.git/info/gitfilesupdate.sh" ] &&
  [ ! -x "${t_work_dir}/.git/info/gitkeep.sh" ] &&
  : "OK"

} &&
echo "[${tests_name}] DONE."

# End
exit $?
