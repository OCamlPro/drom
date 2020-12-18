#!/bin/sh

# Read more on this file in before.sh

COMMAND=$1
shift
SCRIPT=./scripts/after-${COMMAND}.sh

if [ -e ${SCRIPT} ]; then
   exec ${SCRIPT} $*
fi
