#!/bin/sh

# Read more on this file in before.sh

COMMAND=$1
shift $(( $# > 0 ? 1 : 0 ))
SCRIPT=./scripts/after-${COMMAND}.sh

if [ -e ${SCRIPT} ]; then
   exec ${SCRIPT} $*
fi
