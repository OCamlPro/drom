#!/bin/sh

subdirs="$*"

for subdir in ${subdirs}; do
    subdir=_build/install/default/share/${subdir}
    if [ -d ${subdir} ]; then
        cp -rfL ${subdir} .
    fi
done
