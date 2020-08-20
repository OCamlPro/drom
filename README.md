# drom

`drom` is the current code name for a project to discuss and maybe implement a potential cargo-like tool for OCaml

## Proposal 2020/08/20 (Fabrice)

The tool would be mainly used to ease the creation of OCaml projects
and their publication on Opam.

A "standard" project would :
* be hosted on Github (in the first version)
* use Github pages to publish its website and documentation
* use `opam` to manage its dependencies
* use `dune` to build
* use `ocamlformat` for formatting (using `dune build @fmt --auto-promote`)
* use `sphinx` with ReadTheDocs for its documentation
* use `odoc` to generate its API documentation
* use `merlin` for navigation

Everything is managed using a simple `drom.toml` file, containing the
project description, dependencies and tools. The tool will generate an
`$project.opam` file (directly, not using `dune-project`), and all the
other needed files. Once these files have been generated, the user can
choose to continue to use `drom` to update them, or edit them
manually, disabling updates in `drom.toml`.

```
$ drom new project
```

will create the following files in the `project/` directory:
* `drom.toml`
* `project.opam`
* `.git/`
* `.gitignore`
* `dune-workspace`
* `src/dune`
* `src/main.ml` or `src/lib.ml`
* `Makefile`
* `docs/index.md` (root of Github pages)
* `sphinx/index.rst`
* `sphinx/usage.rst`

```
$ cd project
$ drom build
```

will call:
* `opam switch create . --empty`
* `opam install --deps-only .`
* `dune build @fmt`
* `dune build`

Calling `opam` is only done if the `project.opam` file has been modified since
the last call.


```
drom docs
```
will call both `odoc` and `sphinx-build`.

```
$ drom clean
```
removes all build artefacts
