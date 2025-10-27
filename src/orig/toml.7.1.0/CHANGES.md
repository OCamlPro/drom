# Changelog

## Unreleased

## 7.1.0

* enable type inference for Menhir
* compatibility with recent dune version
* remove everything related to cconv
* bump minimal OCaml version to 4.08

## 7.0.0

* treat quoted and bare keys the same with respect to comparison
* bump minimal OCaml version to 4.07
* add support for arrays of inline tables
* add support for dates without times
* fix printer bug with triple quotes

## 6.0.0

* change the structure of the toml library and rename some modules
* rename toml-cconv to toml_cconv
* improve print_string output
* switch to GitHub actions and deploy documentation on gh-pages

## 5.0.0

* migration to dune
* split between toml and toml-cconv
* compatibility with safe-string for OCaml 4.06
* remove dependency on str

## 4.0.0

* Reintroduces public data types (major breaking change).
* Exception-safe parsing interface.
* Add lenses for accessing/updating nested data.

## 3.0.0

* Add support for version 0.4 of the language.

## 2.2.1

* Fixed dependencies.

## 2.2.0

* Numerous convenience functions to reduce verbosity
* Fix wrong error location returned when parsing an invalid Toml file
* Parsing a Toml file always throws `TomlParser.Error` and never `Failure`
* Add array of tables
* Add @since tags in the documentation
* Add changelog

## 2.0.0 and 2.1.0

* Add LGPL licence
* New parser with menhir
* Support for nested arrays
* Support for dates (with Unix.tm type)
* Support for unicodes espaces ('\uXXXX')
* Remove the "toml" prefix from type names
* Add Toml printer
* Abstract internal types in modules (for constraint application and code
  factorization)
* A lot more documentation in source code and Readme
* Display error location when a ParseError occurs

## 1.0.0

* Base parser from ocamllex and ocamlyacc
