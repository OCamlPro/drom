#!/usr/bin/env bash
set -ue

LC_ALL=C

cd $(dirname "$0")/..

## Run build in container

set -o pipefail

# Use `docker-alpine-image` field to replace ocamlpro/ocaml:4.13
# and `docker-alpine-packages` to add more apk packages
git ls-files -z | xargs -0 tar c | \
docker run --rm -i \
    ocamlpro/ocaml:4.13 \
    sh -uexc \
      'tar x >&2 &&
       sudo apk add g++ openssl-libs-static bash  >&2 &&
       opam update >&2 &&
       opam switch create . ocaml-system --deps-only --locked >&2 &&
       opam exec make LINKING_MODE=static >&2 &&
       tar c -hC _build/install/default/bin .' | \
  tar vx

# if you get: "this does not look like a tar archive", you might have forgotten
# a >&2 on a command (nothing should be printed on stdout, except the tar file)
