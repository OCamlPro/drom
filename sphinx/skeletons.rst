
.. _Contributing skeletons:

Contributing Your Own Skeletons
===============================

Overview
--------

There are 2 kinds of skeletons used to create and update :code:`drom`
project:

* *project skeletons* define a whole project composed of one or more packages
* *package skeletons* define only one package, corresponding to every opam
  package generated in the project

:code:`drom` comes with a set of predefined skeletons. Users can
contribute their own skeletons, either by adding them to their local
configuration, or by submitting them to the :code:`drom` project.
  
Skeleton Locations
------------------

When building its set of skeletons, :code:`drom` will search them in two
directories:

* A system directory. It is the first existing one in the following list:

  * :code:`$DROM_SHARE_DIR/skeletons/`, i.e. using the :code:`$DROM_SHARED_DIR` environment variable
  * any directory :code:`./share/drom/skeletons/` in one of the ancestor directories (:code:`.`, :code:`..`, :code:`../..`, etc.). This is used to test new skeletons directly from :code:`drom` sources.
  * :code:`$OPAMROOT/plugins/opam-drom/skeletons/`, where :code:`$OPAMROOT` defaults to :code:`$HOME/.opam/` if undefined. This is used when :code:`drom` is installed as an :code:`opam` plugin, but can also be used when installed globally by the user.
  * :code:`$OPAM_SWITCH_PREFIX/share/drom/skeletons/`. This is used when :code:`drom` is installed in the local switch only.
  * :code:`${share-dir}/skeletons`, where :code:`${share-dir}` is the value of that variable in the user configuration file (:code:`$HOME/.config/drom/config`)

* A user directory: :code:`$HOME/.config/drom/skeletons/`

If a skeleton exists in both directories, the one in the user directory overwrites the one in the system directory. :code:`drom` will then complain about it.

The Skeleton Format
-------------------

The :code:`skeletons/` folder is divided in two directories
:code:`projects/` and :code:`packages/` for the two kinds of skeletons.

Each directory contains one directory per skeleton, containing the
following files:

* :code:`skeleton.toml`: some information on the skeleton (name,
  inheritance, additionnal information on files)
* :code:`files/`: the template files, that will be instantiated for
  that skeleton. For a project skeleton, the files are expected to be
  instantiated at the root of the project (:code:`drom.toml`
  location). For a package skeleton, the files are expected to be
  instantiated in the package directory (:code:`package.toml` location)
* :code:`project.toml`: for project skeletons, this file contains an
  initial configuration for the project variables and packages. If the
  skeleton is inherited from another one, the ancester configuration
  is completed with the child configuration, with priority to the
  child configuration, and so recursively. Note that this file
  contains also the configuration of the packages, since no package
  configuration is read from package skeletons for now.
* :code:`package.toml`: this file is not used.

Let's take an excerpt of a :code:`skeleton.toml` file::

   [skeleton]
   name = "program"
   inherits = "virtual"
   
   [file]
   "Makefile" = { skips = [ "make" ] }
   "dune-project_" = { file = "dune-project", skips = [ "dune" ] }
   ...
  
The file contains the following fields:

* :code:`name` (mandatory): the name of the skeleton
* :code:`inherits` (optional): the name of a skeleton from which this
  skeleton inherits
* :code:`[file]` section (optional): a set of fields to configure the
  use of one of the files in the :code:`files/` directory. Currently,
  the following fields are availble:

  * :code:`file`: the name under which the file should be
    instantiated. This is useful if you cannot use the real name of
    the file in the skeleton, for example because the name would
    conflict with tools used in the project (dot files, :code:`dune`
    files, etc)
  * :code:`skips`: a list of tags that can be used in the
    :code:`drom.toml` :code:`skip` option or :code:`--skip` argument to
    skip this file.
  * :code:`create`: whether the file should only be created if it
    doesn't exist yet (:code:`true`) or every time (:code:`false`,
    default).
  * :code:`subst`: whether substitutions should happen on the file
    (:code:`true`, default) or not (:code:`false`). Useful for binary
    files for example to avoid accidental substitutions.
  * :code:`skip`: whether the file should be always skipped
    (:code:`true`) or not (:code:`false`, default). Useful for a
    documentation file in the skeleton files.
  * :code:`record`: whether the file should recorded in :code:`git`
    files and in the :code:`.drom` state file (:code:`true`,
    default). Useful for documentation files that are only to help the
    user, not to remain in the project.
  
The Skeleton Substitution Language
----------------------------------

Substitutions are performed on files in skeletons if the :code:`subst`
field is not set to :code:`false` in the :code:`skeleton.toml` file
(see above).

There are 3 kinds of substitutions happening:

* Brace substitutions (:code:`!{xxx}`): these substitutions are
  hardcoded in :code:`drom` to generate specific information for the
  project or package. 
* Paren substitutions (:code:`!(xxx)`): these substitutions replace
  the variable with its value, respectively, for a project, in the
  :code:`[fields]` section of the :code:`drom.toml`, or for a package,
  in the :code:`[fields]` section of the :code:`package.toml` or in
  the :code:`[package.fields]` section of the package in the
  :code:`drom.toml` file.
* Bracket substitutions (:code:`![xxx]`): these substitutions always
  return an empty string. They are used for side-effects on the
  substitutions (conditional substitutions, setting flags, etc.)

Brace and paren substitutions can be combined with encodings by using
a :code:`:ENCODING` extension. For example, :code:`!{name:upp}` is
replaced by the name of the project/package in uppercase.

The following encodings are available:
* :code:`html`: html encoding (:code:`&` is replaced by :code:`&amp;`, etc.)
* :code:`cap`: set the first char to uppercase
* :code:`uncap`: set the first char to lowercase
* :code:`low`: lowercase
* :code:`uncap`: uppercase
* :code:`alpha`: replace all non-alpha chars by underscores

For *package* substitutions, brace and paren substitutions for the
*project* are used if no substitution was found for the *package*. It
is possible to force *project* substitution in a *package* using the
:code:`project-` prefix (:code:`!{project-name}` for example in a
package file for the :code:`name` substitution of the
project). Reciprocally, it is possible to use a :code:`package-`
prefix in a Paren (field) substitution to prevent a project
substitution if the field is not defined in the package.
  
Brace Substitutions
~~~~~~~~~~~~~~~~~~~

The ultimate source of information for Brace substitutions is the
`subst.ml module
<https://github.com/OCamlPro/drom/blob/master/src/drom_lib/subst.ml>`__
in the :code:`project_brace` and :code:`package_brace` fuctions.

Currently, the following *project* substitutions are available:

* :code:`!{escape:true}`... :code:`!{escape:false}`: makes :code:`\!{`
  be replaced by :code:`!{` instead of starting a substitution.
* :code:`!{name}`: the project name
* :code:`!{synopsis}`: the project synopsis
* :code:`!{description}`: the project description
* :code:`!{version}`: the project version
* :code:`!{edition}`: the default OCaml version to use
* :code:`!{min-edition}`: the minimal OCaml version
* :code:`!{github-organization}`: the current github-organization
* :code:`!{authors-as-strings}`: the list of authors
* :code:`!{authors-for-toml}`: the list of authors in TOML
* :code:`!{authors-ampersand}`: the authors separated by ampersands
* :code:`!{copyright}`: the project copyright
* :code:`!{license}`: the project full license file
* :code:`!{license-name}`: the SPDF name of the project license
* :code:`!{header-ml}`: the header for an ML file (also MLL file)
* :code:`!{header-c}`: the header for a C file (also MLY file)
* :code:`!{year}`, :code:`!{month}`, :code:`!{day}`: current date
* There are many other substitutions, for example specific to Dune
  files (like :code:`!{dune-packages}` for the :code:`dune-project`
  file). Some of them will disappear because they can be generated
  using conditionals (:code:`![if:...]`, see bracket substitutions),
  some of them will be documented later (TODO).
  
Currently, the following *package* substitutions are available:

* :code:`!{name}`: the package name
* :code:`!{dir}`: the package dir
* :code:`!{skeleton}`: the package skeleton
* :code:`!{library-name}`: the package library name (uncapitalized version of
  the :code:`pack` option or underscorified version of the package name)
* :code:`!{library-module}`: the package module name (:code:`pack` option
  or capitalized version of the package name)

Paren Substitutions (project and package fields)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Paren substitutions are substituted by the :code:`[fields]` variables
in the project/package description files. If the field is not defined,
the substitution is replaced by the empty string. Such fields are
often used for trailers in generated files, to keep using :code:`drom`
to update them while still adding specific information by hand.

Currently, the following paren substitutions are used in *project*
skeletons:

* :code:`!(dot-gitignore-trailer)`: a trailer added at the end of the
  :code:`.gitignore` file
* :code:`!(dune-dirs)`: a string added in the :code:`(dirs ...)`
  stanza of the root :code:`dune` files to specify which dirs should
  be scanned.
* :code:`!(makefile-trailer)`: a trailer added at the end of the
  generated :code:`Makefile`

Currently, the following paren substitutions are used in *package*
skeletons:

* :code:`!(dune-libraries)`: a string added in the :code:`(libraries
  ...)` stanza of the generated :code:`dune` file
* :code:`!(dune-stanzas)`: a string added in the :code:`(executable
  ...)` or :code:`(library ...)` stanza of the generated
  :code:`dune` file
* :code:`!(dune-trailer)`: a string added at the end of the generated
  :code:`dune` file

Bracket Substitutions
~~~~~~~~~~~~~~~~~~~~~

The following bracket substitutions are currently available:

* :code:`![if:CONDITION]`... :code:`![else]` ... :code:`![fi]`:
  depending on the condition, replace by the first or second part.
  The condition can be:
  
  * :code:`not:CONDITION`: negation of a condition
  * :code:`skip:TAG`: true if the tag should be skipped
  * :code:`gen:TAG`: true if the tag should not be skipped
  * :code:`true` and :code:`false`: constants
  * :code:`skeleton:is:SKELETON`: true is the current skeleton is the argument
  * :code:`kind:is:KIND`: true if the kind of the *package* is the argument (kind is one of :code:`library`, :code:`program` or :code:`virtual`)
  * :code:`pack`: true if the *package* should be packed
  * :code:`windows-ci`: true if the *project* should run Windows CI
  * :code:`github-organization`, :code:`homepage`, :code:`copyright`, :code:`bug-reports`, :code:`dev-repo`, :code:`doc-gen`, :code:`doc-api`, :code:`sphinx-target`, :code:`profile`: true if the corresponding value is defined for the project
  * :code:`project:CONDITION`: in a *package*, check if the condition is true for the project instead
