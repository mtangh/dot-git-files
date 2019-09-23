
 #!/bin/bash
THIS="${BASH_SOURCE##*/}"
CDIR=$([ -n "${BASH_SOURCE%/*}" ] && cd "${BASH_SOURCE%/*}" &>/dev/null; pwd)

# Run tests
: "Basic syntax check" && {

  bash -n gitkeep.sh &&
  : "OK"

} &&
: "Gitkeeping" && {

  rm -rf ./t 1>/dev/null 2>&1 || :
  mkdir -p t/{dir1,dir2,dir3/child1,dir3/child2} || :

  : "Create Gitkeep" && {

    touch t/dir1/file1.txt &&
    touch t/dir3/child1/file2.txt &&
    bash -x -- "${tests_base_dir}/gitkeep.sh" ./t &&
    [ ! -r "t/dir1/.gitkeep" ] &&
    [   -r "t/dir2/.gitkeep" ] &&
    [ ! -r "t/dir3/child1/.gitkeep" ] &&
    [   -r "t/dir3/child2/.gitkeep" ] &&
    : "OK"

  } &&
  : "Rebuild Gitkeep" && {

    mv -f t/dir{1,2}/file1.txt &&
    mv -f t/dir3/child{1,2}/file2.txt &&
    bash -x -- "${tests_base_dir}/gitkeep.sh" --rebuild ./t &&
    [   -r "t/dir1/.gitkeep" ] &&
    [ ! -r "t/dir2/.gitkeep" ] &&
    [   -r "t/dir3/child1/.gitkeep" ] &&
    [ ! -r "t/dir3/child2/.gitkeep" ] &&
    : "OK"

  }

} &&
: "DONE."

# End
exit $?
