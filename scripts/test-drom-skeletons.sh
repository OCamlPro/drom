#!/bin/bash

if [ "X$1" == "X" ]; then
  SKELETONS=$(drom config --drom-project-skeletons)
else
  SKELETONS="$1"
fi

set -euo pipefail

SWITCH=4.10.0

cd /tmp
mkdir -p /tmp/drom-tests
cd /tmp/drom-tests
rm -rf *

for skeleton in $SKELETONS; do

  echo
  echo
  echo "                $skeleton"
  echo
  echo
  cd /tmp/drom-tests
  drom new test-$skeleton --skeleton $skeleton
  cd test-$skeleton
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
