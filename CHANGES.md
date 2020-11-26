
## v0.2.1 ( 2020-11-25 )

* Field `gen-version = "version.ml"` in `package.toml` does not create the
   file "version.ml" anymore, but a script "version.mlt" to generate the
   file with git information
* New command `drom lock` to generate a file `${package}-deps.opam.locked`
  and git add it.
* New argument `--locked` to `drom build` to use `${package}-deps.opam.locked`
  if available.
* Fixes:
  * OCaml escaping in toml file preventing `drom new` when utf8 chars are
    present in email addresses of authors

## v0.2.0 ( 2020-11-24 )

* Fix bug with misnamed 'packages.toml` file in skeletons

## v0.1.0 ( 2020-11-23 )

* First version

