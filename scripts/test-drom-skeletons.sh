#!/bin/bash
set -euo pipefail

SWITCH=4.10.0

cd /tmp
mkdir -p /tmp/drom-tests
cd /tmp/drom-tests
rm -rf *


SKELETONS=$(drom config --drom-project-skeletons)

for skeleton in $SKELETONS; do

  echo
  echo
  echo "                $skeleton"
  echo
  echo
  cd /tmp/drom-tests
  drom new $skeleton --skeleton $skeleton
  cd $skeleton
  echo drom project --upgrade
  drom project --upgrade || exit 2
  echo drom build -y
  drom build -y || exit 2
  if [ -d test ]; then
      echo drom test -y
      drom test -y || exit 2
  fi
  if [ -d sphinx ]; then
      echo drom sphinx -y
      drom sphinx -y || exit 2
  fi
  echo drom odoc -y
  drom odoc -y || exit 2

done
