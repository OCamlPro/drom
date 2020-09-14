The 'default' skeleton is used as a template to create and update projects.

The current, too simple, skeleton is composed of 2 directories:
* 'project/' contains the files to put in a project
* 'package/' contains the files to put in the source tree of the package
   (i.e. 'src/PACKAGE/').
   (remark: it is likely to change if we want to support multi-package
    skeletons at some point)

Within each directory, the following substitutions are applied to the
content of each file:


  * !{EXPR} is substituted by the meaning of EXPR for the package/project.
    (remark: we need to explain more)
    EXPR has the following format: 'IDENT[:ENCODING]*'
    where IDENT is interpreted for the package/project, and ENCODING is
    applied to the result on its left.
    Current encodings are:
    "html": html-encode the string
    "cap": capitalize the string
    "uncap": uncapitalize the string
    "low": lowercase the string
    "up": uppercase the string
    "alpha": replace any non-alpha numerical character by '_'

   IDENT : check the two first pattern-matchings in 'src/drom_lib/subst.ml'
     for its meaning for projects and packages


  * !(FIELD) is substituted by the corresponding field in the project drom.toml
    For example, a field 'foo' is specified as:
    ```
    [project.fields]
    foo = "bar"
    ```
     will make '!(foo)' be replaced by 'bar' in the project. Use
     '[package.fields]' for packages.

     For example, the `dune` template uses the following fields:
     * `dune-stanzas`: additionnal stanzas to be included in the
       `(executable ...)`
     * `dune-trailer`: additionnal content to be included at the end of file

    For a package substitution, FIELD will first be interpreted a field of the
    package, then as a field of the project if not found.
    FIELD can be prefixed by `project-` or `package-` to avoid that:
    * `project-FIELD` will lookup `FIELD` only in the project fields
    * `package-FIELD` will lookup `FIELD` only in the package fields
    When a field is not found, it is silently replaced by ""

  * ![flag] is substituted by nothing, but has a side effect:
    * ![skip:TAG] : the file will be skipped if TAG is in the 'skip' field
      of 'drom.toml'
    * ![create] : the file will be created if not existing, but never updated
      afterwards
    * ![no-record] : the file will be generated, but not recorded. It should
      not be added to git. Mostly useful for '_drom/' files.
    * ![file:FILENAME] : the file should be called FILENAME instead.
      For skeletons included in the sources of `drom`, you MUST use this
      flag for files starting with '.' or '_' instead of
      using their real name, because 'dune' will complain otherwise.

Usual problems:

If a substitution does not happen correctly:

* check that you have used the correct syntax, i.e. '!' instead of '$'

* check that you have chosen the correct category :
  `!{EXPR}` for expressions to be evaluated, `!(FIELD)` for fields
   (note that `project.name` in the `drom.toml` does not create a `name`
   field in the project. Fields are only created by the `project.fields`
   section. `name` can only be accessed by the `${name}` expression),
   and `![flag]` for side-effects.

Note that you can set the env variable `DROM_VERBOSE_SUBST` for `drom project`
to display missed fields lookups.
