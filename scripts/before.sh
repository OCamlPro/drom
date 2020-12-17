#!/bin/sh

# This script and after.sh are used to mimic drom hooks from the Makefile
# and opam file.
# drom calls the following hooks:
#  * before-build.sh [PACKAGE] (PACKAGE only provided if called from opam for PACKAGE.opam)
#  * after-build.sh  [PACKAGE]
#  * before-sphinx.sh SPHINX_TARGET
#  * after-sphinx.sh SPHINX_TARGET
#  * before-odoc.sh ODOC_TARGET
#  * after-odoc.sh ODOC_TARGET
#  * before-test.sh
#  * after-test.sh
#  * before-install.sh PACKAGE
#  * after-clean.sh
#  * after-distclean.sh
#  * before-fmt.sh
#  * after-fmt.sh
#  * before-run.sh CMD ARGS
#  * before-publish.sh OPAM_REPO
#  * after-publish.sh OPAM_REPO

COMMAND=$1
shift
SCRIPT=./scripts/before-${COMMAND}.sh

if [ -e ${SCRIPT} ]; then
   exec ${SCRIPT} $*
fi
