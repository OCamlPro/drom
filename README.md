
[![Actions Status](https://github.com/ocamlpro/drom/workflows/Main%20Workflow/badge.svg)](https://github.com/ocamlpro/drom/actions)
[![Release](https://img.shields.io/github/release/ocamlpro/drom.svg)](https://github.com/ocamlpro/drom/releases)

# drom

The drom tool is a wrapper over opam/dune in an attempt to provide a cargo-like
user experience. It can be used to create full OCaml projects with
sphinx and odoc documentation. It has specific knowledge of Github and
will generate files for Github Actions CI and Github pages.


* Website: https://ocamlpro.github.io/drom
* General Documentation: https://ocamlpro.github.io/drom/sphinx
* API Documentation: https://ocamlpro.github.io/drom/doc
* Sources: https://github.com/ocamlpro/drom


## Simple Example

You can create a new OCaml project with:

```
$ drom new my-client --skeleton mini_prg
Creating project "my-client" with skeleton "mini_prg", license "LGPL2"
  and sources in src/my-client:
Creating directory my-client
Using skeleton "program" for package "my-client"
[master (root-commit) 8d83262] Initial commit

└── my-client/
    ├── .drom             (drom state, do not edit)
    ├── .github/
    │   └── workflows/
    │       └── workflow.yml
    ├── .gitignore
    ├── CHANGES.md
    ├── LICENSE.md
    ├── Makefile
    ├── README.md
    ├── drom.toml    <────────── project config EDIT !
    ├── dune
    ├── dune-project
    ├── opam/
    │   └── my-client.opam
    ├── scripts/
    │   ├── after.sh
    │   ├── before.sh
    │   └── copy-bin.sh
    └── src/
        └── my-client/
            ├── dune
            ├── main.ml
            ├── package.toml    <────────── package config EDIT !
            └── version.mlt
```

This project uses the minimalist `mini_prg` skeleton, but other skeletons
like `program` or `library` have more files.


