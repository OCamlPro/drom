
.PHONY: all build-deps doc sphinx odoc view fmt fmt-check install dev-deps test
DEV_DEPS := merlin ocamlformat odoc

all: build

build:
	dune build
	cp -f _build/default/main/main.exe drom


build-deps:
	opam install --deps-only ./*.opam

sphinx:
	sphinx-build sphinx docs/sphinx

doc:
	dune build @doc
	rsync -auv --delete _build/default/_doc/_html/. docs/doc

view:
	xdg-open file://$$(pwd)/docs/index.html

fmt:
	dune build @fmt --auto-promote

fmt-check:
	dune build @fmt

install:
	dune install

opam:
	opam pin -k path .

uninstall:
	dune uninstall

dev-deps:
	opam install -y ${DEV_DEPS}

test:
	dune build @runtest
