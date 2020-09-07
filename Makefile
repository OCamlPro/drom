
.PHONY: all build-deps doc sphinx odoc view fmt fmt-check install dev-deps test
DEV_DEPS := merlin ocamlformat odoc ppx_expect ppx_inline_test

all: build

build:
	opam exec -- dune build @install
	cp -f _build/default/main/main.exe drom

build-deps:
	opam install ./*.opam --deps-only

sphinx:
	sphinx-build sphinx docs/sphinx

doc:
	opam exec -- dune build @doc
	rsync -auv --delete _build/default/_doc/_html/. docs/doc

view:
	xdg-open file://$$(pwd)/docs/index.html

fmt:
	opam exec -- dune build @fmt --auto-promote

fmt-check:
	opam exec -- dune build @fmt

install:
	opam exec -- dune install

opam:
	opam pin -k path .

uninstall:
	opam exec -- dune uninstall

dev-deps:
	opam install ./*.opam --deps-only --with-doc --with-test

test:
	opam exec -- dune build @runtest
