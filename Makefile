
all:
	dune build
	cp -f _build/default/src/main.exe drom

build-deps:
	opam install --deps-only ./opam

init:
	git submodule init
	git submodule update

doc: html
	markdown docs/index.md > docs/index.html

html:
	sphinx-build sphinx docs/doc

view:
	xdg-open file://$$(pwd)/docs/doc/index.html
