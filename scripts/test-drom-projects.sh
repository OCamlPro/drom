#!/bin/bash
set -euo pipefail

SWITCH=4.10.0

cd /tmp
mkdir -p /tmp/drom-tests
cd /tmp/drom-tests
rm -rf *

PACKAGES="
https://github.com/ocamlpro/ez_subst
https://github.com/ocamlpro/ez_cmdliner
https://github.com/ocamlpro/drom
https://github.com/ocamlpro/opam-bin
https://github.com/ocamlpro/digodoc
"

for package in $PACKAGES; do

  echo
  echo
  echo "                $(basename $package)"
  echo
  echo
  cd /tmp/drom-tests
  git clone $package
  cd $(basename $package)
  drom project --upgrade || exit 2
  drom build -y || exit 2
  drom test -y || exit 2
  drom sphinx -y || exit 2
  drom odoc -y || exit 2

done
