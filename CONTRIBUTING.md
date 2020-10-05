How to contribute to drom ?
===========================

There are many ways to contribute to drom. Here are a few starting
points:

Adding support for a new tool/environement
------------------------------------------

Suppose you think most OCaml projects should use a given tool. So, you
may want to contribute support for this tool into projects generated
by `drom`.

Here is how to do it:

* There are projects' skeletons in `src/drom_lib/skeletons/projects`,
  in particular the `virtual/` skeleton used as the basis for all
  other skeletons. You can add a new template file in that skeleton.
  Template files are used by substitutions of 3 kinds, !{EXPR},
  !(FIELD) and ![FLAG]. Have a look at other templates for examples.

* Once you have added a file in the skeleton, modify the
  `dune-trailer` field of the `drom_lib` package in `drom.toml` to add
  the new file as a dependency of the corresponding skeleton. You will
  need to call `drom project` to regenerate the `dune` file after
  every change.

* You may also want to add specific substitutions for your template
  file. This is done by modifying the project substitution
  `project_brace` in `src/drom_lib/subst.ml`.

Adding more known licenses
--------------------------

Known licenses are included by scanning the `src/drom_lib/licenses/`
directory. Have a look there for example. Every license is defined by:

* the name of its directory, which is the key used in the `license`
  field in `drom.toml`
* a file `NAME` with the long name of the license
* a file `HEADER` with the lines to add in the header of every source file
* a file `LICENSE` with the complete text of the license

Once you have added a new license, edit the `dune-trailer` field in
`drom.toml` to add the license files as dependencies (check where the
other licenses appear). You will need to call `drom project` after
that to regenerate the corresponding `dune` file.
