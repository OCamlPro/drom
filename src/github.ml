(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

let template_DOTgithub_workflows_workflow_yml =
  {|!{github:skip}!{workflows:skip}
name: Main Workflow

on:
  push:
    branches:
      - master
  pull_request:
    branches:
      - master

jobs:
  build:
    strategy:
      fail-fast: false
      matrix:
        os:
          - macos-latest
          - ubuntu-latest
!{comment-if-not-windows-ci}          - windows-latest
        ocaml-version:
          - !{edition}
        skip_test:
          - false
!{include-for-min-edition}

    env:
      SKIP_TEST: ${{ matrix.skip_test }}
      OCAML_VERSION: ${{ matrix.ocaml-version }}
      OS: ${{ matrix.os }}

    runs-on: ${{ matrix.os }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v2

      - name: Cache
        uses: actions/cache@v2
        with:
          path: /home/runner/.opam
          key: ${{ runner.os }}-!{name}-opam-cache-${{ hashFiles('*.opam') }}
      - name: Use OCaml ${{ matrix.ocaml-version }}
        uses: avsm/setup-ocaml@v1
        with:
          ocaml-version: ${{ matrix.ocaml-version }}

      - name: Set git user
        run: |
          git config --global user.name github-actions
          git config --global user.email github-actions-bot@users.noreply.github.com

      - run: opam pin add . -y --no-action

      - run: opam depext -y !{packages}

      - run: opam install -y ./*.opam --deps-only --with-test

      - run: opam exec -- dune build @install

      - name: run test suite
        run: opam exec -- dune build @runtest
        if: env.SKIP_TEST != 'true'

      - name: test source is well formatted
        run: opam exec -- dune build @fmt
        continue-on-error: true
        if: env.OCAML_VERSION == '!{edition}' && env.OS == 'ubuntu-latest'
|}

let project_files =
  [
    (".github/workflows/workflow.yml", template_DOTgithub_workflows_workflow_yml);
  ]
