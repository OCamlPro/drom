
## v0.2.1 ( 2020-11-25 )

* Add table `[file]` in `skeleton.toml` to specify flags for skeleton files
    from the outside (useful for binary files for example). Flags can be
    `file` (name of file), `create` (create only if non-existing), `skips`
    (list of tags forcing skip), `subst` (do not perform substitution)
* Extend skeleton substitution language with ![if:COND]...![else]...![fi]
    COND can be `gen:SKIPTAG`, `skip:SKIPTAG`, `skeleton:is:SKELETON`,
    `kind:is:KIND`, `not:COND`, `pack` (packed)
* New skeleton projects `mini-lib` and `mini-prg` with
   `skip = "test sphinx github docs ocamlformat ocp-indent code"`
* Improved inline documentation of `drom.toml` and `package.toml` files
* New command `drom opam-plugin` to install `drom` as an opam plugin, so it
  can be called `opam drom` from anywhere.
* New argument `--profile PROFILE` to `drom build`
* New argument `--all` to `drom test` to do the test on all available/compatible
   opam switches (using dune-workspace context feature)
* New option `dev-tools` in ~/.config/drom/config, a list of opam packages
   that should be installed in the local switch when `drom dev-deps` is called
* New environment variable DROM_SHARE_DIR can be used to set the directory
   containing `skeletons` and `licenses` directories (can be used to install
   drom globally, i.e. DROM_SHARE_DIR=$OPAM_SWITCH_PREFIX/share/drom)
* New common argument `-q` or `--quiet` to set verbosity to 0
* New command `drom dep [DEP]`: display and update dependencies with options:
  --package NAME : only for package NAME
  --tool : tool dependencies
  --add : add new dependency
  --remove : remove dependency
  --ver VERSION : set version constraint
  --lib LIBNAME : set dune name
  --test BOOL : set for-test
  --doc BOOL : set for-doc
* New option `drom package x --new-file y.ml` to create a source file with
  a correct license header
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

