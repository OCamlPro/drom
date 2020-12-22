#!/bin/sh

PACKAGES="$*"

for package in ${PACKAGES}; do
    file=_build/default/src/${package}/main.exe
    if [ -f ${file} ]; then
        cp -f ${file} ${package}
    fi
done
