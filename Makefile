
all:
	dune build
	cp -f _build/default/main/main.exe drom

build-deps:
	opam install --deps-only ./drom.opam

doc: html
	markdown docs/index.md > docs/index.html

html:
	sphinx-build sphinx docs/doc

view:
	xdg-open file://$$(pwd)/docs/doc/index.html
