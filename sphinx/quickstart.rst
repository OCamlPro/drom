
Quickstart
==========

Overview
--------

:code:`drom` has two purposes:

* It's a tool to easily create OCaml projects: :code:`drom new
  PROJECT` will create a complete OCaml project, with all the required
  files for :code:`opam` and :code:`dune`, plus additional files for
  project management on Github, documentation (Sphinx and Github
  Pages) and CI (Github Actions).

* It's a tool to build and install the project, combining calls to
  `opam` and `dune` to create a local switch, install dependencies,
  build the project and its documentation

:code:`drom` uses subcommands::

  $ drom
  DROM(1)                           Drom Manual                          DROM(1)
  
  
  
  NAME
         drom - Create and manage an OCaml project
  
  SYNOPSIS
         drom COMMAND ...
  
  COMMANDS
         build
             Build a project
  
         build-deps
             Install build dependencies only
  
         clean
             Clean the project from build files
  
         dev-deps
             Install dev dependencies (odoc, ocamlformat, merlin, etc.)
  
         doc Generate library API documentation using odoc in the docs/doc
             directory
  
         fmt Format sources with ocamlformat
  
         help
             display help about drom and drom commands
  
         install
             Build & install the project in the project opam switch
  
         package
             Create or update a package within a project

         project
             Create or update a project
  
         publish
             Generate a set of packages from all found drom.toml files
  
         run
             Execute the project
  
         sphinx
             Generate general documentation using sphinx
  
         test
             Run tests
  
         tree
             Display dependencies in the project as a tree
  
         uninstall
             Uninstall the project from the project opam switch
  
         update
             Update packages in the project opam switch
  
  COMMON OPTIONS
         --help[=FMT] (default=auto)
             Show this help in format FMT. The value FMT must be one of `auto',
             `pager', `groff' or `plain'. With `auto', the format is `pager` or
             `plain' whenever the TERM env var is `dumb' or undefined.
  
         --version
             Show version information.

Creating a Project
------------------

Let's suppose we want to create a new project :code:`hello_world`. We
can use `drom` to create almost everything we need for that!

Let's create the project::

  $ drom new hello_world
  Creating project "hello_world" with skeleton "program", license "LGPL2"
    and sources in src/hello_world:
  Creating directory hello_world
  Calling git init
  Initialized empty Git repository in /home/lefessan/tmp/hello_world/.git/
  Calling git remote add origin git@github.com:ocamlpro/hello_world
  Calling git commit --allow-empty -m Initial commit
  [master (root-commit) 732c93c] Initial commit
  Creating file dune-project
  Creating file src/hello_world/index.mld
  Creating file hello_world.opam
  Creating file src/hello_world_lib/version.ml
  Creating file src/hello_world_lib/index.mld
  Creating file hello_world_lib.opam
  Creating file sphinx/_static/css/fixes.css
  Creating file test/output-tests/test2.ml
  Creating file test/output-tests/test2.expected
  Creating file test/output-tests/test1.expected
  Creating file test/output-tests/dune
  Creating file test/inline-tests/test.ml
  Creating file test/inline-tests/dune
  Creating file test/expect-tests/test.ml
  Creating file test/expect-tests/dune
  Creating file .github/workflows/workflow.yml
  Creating file .github/workflows/doc-deploy.yml
  Creating file docs/sphinx/index.html
  Creating file docs/doc/index.html
  Creating file sphinx/license.rst
  Creating file sphinx/install.rst
  Creating file sphinx/index.rst
  Creating file sphinx/conf.py
  Creating file sphinx/about.rst
  Creating file docs/style.css
  Creating file docs/index.html
  Creating file docs/favicon.png
  Creating file docs/README.txt
  Creating file dune
  Creating file .ocp-indent
  Creating file .ocamlformat-ignore
  Creating file .ocamlformat
  Creating file .gitignore
  Creating file README.md
  Creating file Makefile
  Creating file LICENSE.md
  Creating file CHANGES.md
  Creating file src/hello_world/main.ml
  Creating file src/hello_world/dune
  Creating file src/hello_world_lib/main.ml
  Creating file src/hello_world_lib/dune
  Forced Update of file drom.toml
  Forced Update of file src/hello_world_lib/package.toml
  Forced Update of file src/hello_world/package.toml
  Calling git add .drom test/output-tests/test2.ml test/output-tests/test2.expected test/output-tests/test1.expected test/output-tests/dune test/inline-tests/test.ml test/inline-tests/dune test/expect-tests/test.ml test/expect-tests/dune src/hello_world_lib/version.ml src/hello_world_lib/package.toml src/hello_world_lib/main.ml src/hello_world_lib/index.mld src/hello_world_lib/dune src/hello_world/package.toml src/hello_world/main.ml src/hello_world/index.mld src/hello_world/dune sphinx/license.rst sphinx/install.rst sphinx/index.rst sphinx/conf.py sphinx/about.rst sphinx/_static/css/fixes.css hello_world_lib.opam hello_world.opam dune-project dune drom.toml docs/style.css docs/sphinx/index.html docs/index.html docs/favicon.png docs/doc/index.html docs/README.txt README.md Makefile LICENSE.md CHANGES.md .ocp-indent .ocamlformat-ignore .ocamlformat .gitignore .github/workflows/workflow.yml .github/workflows/doc-deploy.yml

As you can see, :code:`drom` created a directory :code:`hello_world`
with the following files:

* :code:`drom.toml` for project management by :code:`drom`, and two files
  :code:`package.toml` for each sub-package in their sources.
* Source files for the project, composed of an :code:`hello_world_lib`
  library in :code:`src/hello_world_lib/` and a driver executable in
  :code:`src/hello_world/main.ml`
* :code:`git` source version management files: :code:`.gitignore` and
  :code:`.git/` for the :code:`git` revision control tool
* Documentation files: :code:`docs/index.html` and
  :code:`docs/style.css` for the project homepage
* :code:`sphinx/` directory for the Sphinx documentation formatter
* :code:`README.md`, :code:`CHANGES.md` and :code:`LICENSE.md` project files
* Specific files for :code:`opam` and :code:`dune`:
  :code:`dune-project`, :code:`hello_world.opam` and
  `src/hello_world/dune` for example
* :code:`.github/` for Github Actions CI
* :code:`.ocamlformat` for the :code:`ocamlformat` code formatting
  tool and :code:`.ocp-index` for source lookups
* Examples of test files in the :code:`test/` directory

At this point, you may decide that :code:`drom` has done enough for
you, and you can go back to using :code:`opam` and :code:`dune` to
work on your project.
  
The :code:`drom.toml` file has a particular importance, it can be used
by :code:`drom` to update all the generated files with this
information. It contains information on the project, such as its name,
license, description, dependencies, etc.

Everytime you modify :code:`drom.toml`, you should call :code:`drom
project` again to update the project::

  $ cd hello_world
  $ emacs drom.toml
  $ drom project
  drom: Entering directory '/tmp/hello_world'
  Updating file dune-project
  Updating file hello_world.opam
  Updating file hello_world_lib.opam
  Updating file src/hello_world/dune
  Updating file src/hello_world_lib/dune
  Calling git add .drom src/hello_world_lib/dune src/hello_world/dune hello_world_lib.opam hello_world.opam dune-project .

Here, we added a dependency in the `drom.toml` file::

  ...
  [dependencies]
  ez_file = ""
  ...

And we see that :code:`drom` updated the files for :code:`dune` and
:code:`opam`.

:code:`drom project` also takes a few command line options that can be
used to modify the :code:`drom.toml` file:

* :code:`--skeleton SKELETON` can be used to change the skeleton used
  to manage files. :code:`drom` knows about 3 differents skeletons by
  default: :code:`library` (a simple library), :code:`program` (a
  driver calling a library, the default skeleton used when nothing is
  specified) and :code:`virtual` (no default package).  An up-to-date
  list of project skeletons can be found in the generated file
  :code:`_drom/known-skeletons.txt`.
* :code:`--upgrade` can be used to upgrade the :code:`drom.toml` file
  when you are using a more recent version of :code:`drom`
* :code:`--binary` and :code:`--javascript` can be used to switch
  between generating binaries and generating Javascript using
  :code:`js_of_ocaml` by default.

Notice that, just after creating the project, you should be able to
build it and run it with no error!

Building a Project
------------------------------------

:code:`drom` can be used to build a project. In this case, it will use
:code:`opam` to manage the environment (dependencies) and :code:`dune`
to build the project. You don't need to know these tools for basic
usage of :code:`drom`.

Because :code:`drom` makes extensive use of local :code:`opam`
switches, it is a good idea to use it from :code:`opam-bin` to benefit
from binary caching of packages, to speedup creation of local
switches.

Building locally
~~~~~~~~~~~~~~~~

By default, :code:`drom` will try to build the project in its directory::

  $ cd hello_world
  $ drom build -y
  Calling opam switch create -y . --empty
  Calling opam install -y ocaml.4.10.0
  The following actions will be performed:
    ∗ install base-bigarray       base
    ∗ install base-threads        base
    ∗ install base-unix           base
    ∗ install ocaml-base-compiler 4.10.0                     [required by ocaml]
    ∗ install ocaml-config        1                          [required by ocaml]
    ∗ install ocaml               4.10.0
  ===== ∗ 6 =====
  
  <><> Gathering sources ><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
  [ocaml-base-compiler.4.10.0] found in cache

  <><> Processing actions <><><><><><><><><><><><><><><><><><><><><><><><><><><><>
  ∗ installed base-bigarray.base
  ∗ installed base-threads.base
  ∗ installed base-unix.base
  ∗ installed ocaml-base-compiler.4.10.0
  ∗ installed ocaml-config.1
  ∗ installed ocaml.4.10.0
  Done.
  # Run eval $(opam env) to update the current shell environment
  Calling opam switch set-base ocaml
  Calling opam install -y --deps-only ./_drom/new.opam
  The following actions will be performed:
  ∗ install dune 2.7.0
  
  <><> Gathering sources ><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
  [dune.2.7.0] found in cache
  
  <><> Processing actions <><><><><><><><><><><><><><><><><><><><><><><><><><><><>
  ∗ installed dune.2.7.0
  Done.
  # Run eval $(opam env) to update the current shell environment
  Calling opam exec -- dune build
  Done: 40/46 (jobs: 1)
  Build OK

During this build, :code:`drom` performed the following operations:

* It loads the project definition file :code:`drom.toml`
* It creates a local :code:`opam` switch (directory :code:`_opam`)
  where it installs the version of OCaml specified in the
  :code:`edition` field of the project definition
* It installs all the dependencies of the package. In our simple example,
  it is only the :code:`dune` build tool.
* Once the environment is ok, it builds the project using :code:`dune`.

Since building the environment can take some time, it is important to
know that it is only done the first time. It will also be upgraded
only if the dependencies are changed.

We can now run the program::
  
  $ drom run
  In opam switch /tmp/hello_world/_opam
  Calling opam exec -- dune build
  Done: 0/0 (jobs: 0)
  Calling opam exec -- dune exec -p hello_world -- hello_world
  Hello world!

It's a bit verbose, but the last line :code:`Hello world!` was printed
by our project!

Building with a global :code:`opam` switch
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

:code:`drom` can use global switches also. For example, if you want to
install the project in that switch::

  $ drom build --switch 4.10.0
  Error: You must remove the local switch `_opam` before using option --switch

Since we previously built the project locally, we have a local
:code:`_opam` switch. :code:`drom` will not remove this switch
automatically, because it is often long to rebuild. So, you will have
to do it yourself (or backup it if you are not using
:code:`opam-bin`)::

  $ rm -rf _opam
  $ drom build --switch 4.10.0
  Calling opam switch link 4.10.0
  Directory /tmp/hello_world set to use switch 4.10.0.
  Just remove /tmp/hello_world/_opam to unlink.
  In opam switch 4.10.0
  Calling opam install --deps-only ./_drom/new.opam
  Nothing to do.
  # Run eval $(opam env) to update the current shell environment
  Calling opam exec -- dune build
  Build OK

:code:`drom` performed exactly the same steps as for a local build.
In our case, the :code:`opam` switch :code:`4.10.0` already existed on
our computer, and the dependencies were already installed, so it only
built the project.

However, if the switch specified by :code:`--switch` does not exist
globally, :code:`drom` will call :code:`opam` to create it.

Installing the Project
~~~~~~~~~~~~~~~~~~~~~~

Now that we have tested that our project correctly builds in a local
switch and in a global switch, we can ask :code:`drom` to install it
in the switch::
  
  $ drom install
  Directory /tmp/hello_world set to use switch 4.07.0.
  Just remove /tmp/hello_world/_opam to unlink.
  In opam switch 4.07.0
  Calling opam install --deps-only ./_drom/new.opam
  Nothing to do.
  Calling opam exec -- dune build
  Calling opam uninstall -y hello_world
  The following actions will be performed:
    ⊘ remove hello_world 0.1.0
  
  <><> Processing actions <><><><><><><><><><><><><><><><><><><><><><><><><><><><>
    ⊘ removed   hello_world.0.1.0
  Done.
  Calling opam pin -y --no-action -k path .
  Package hello_world does not exist, create as a NEW package? [Y/n] y
  [hello_world.~dev] synchronised from file:///tmp/hello_world
  hello_world is now pinned to file:///tmp/hello_world (version 0.1.0)
  Calling opam install -y hello_world
  
  <><> Synchronising pinned packages ><><><><><><><><><><><><><><><><><><><><><><>
  [hello_world.0.1.0] no changes from file:///tmp/hello_world
  
  The following actions will be performed:
    ∗ install hello_world 0.1.0*
  
  <><> Processing actions <><><><><><><><><><><><><><><><><><><><><><><><><><><><>
  ∗ installed hello_world.0.1.0
  Done.
  Calling opam unpin -n hello_world
  Ok, hello_world is no longer pinned to file:///tmp/hello_world (version 0.1.0)
  Installation OK

As we can see in this example, :code:`drom` performed the following steps:

* Building the project, as in the previous sections
* Removing all the packages of the project that may already be installed
* Pinning all the packages for :code:`opam`
* Installing the pinned packages (rebuilding them in :code:`opam`)
* Unpinning all the packages

Building Documentation
----------------------

:code:`drom` generates a web-site for your project with 2 parts that
you need to generate separately: a documentation of the library API
automatically generated by :code:`odoc` and a general documentation
that you can modify, generated by the `sphinx-doc tool
<https://www.sphinx-doc.org/en/master/>`__, with the `Read-the-doc
theme <https://readthedocs.org/>`__ . You will need to install them,
it's usually something like::

  pip install sphinx
  pip install sphinx_rtd_theme

The documentation is generated in the :code:`_drom/docs/` directory.
If you are on Github, `drom` generates a Github action that will
automatically merge this directory into the :code:`gh-pages` branch after
every merge/push in the :code:`master` branch, so that you can easily use
Github Pages to host your project documentation.

The main webpage is created from :code:`docs/index.html`, and the Sphinx
files used to generate the documentation are in :code:`sphinx/`. You
can edit these files before generating the documentation.

To generate the documentation, you must call two commands:

* :code:`drom odoc`, each time you want to generate the documentation
  of the API
* :code:`drom sphinx`, each time you want to compile the Sphinx files

The command :code:`drom doc` can be used to generate everything.  You
can use these commands with an extra argument :code:`--view` to open a
local browser on the documentation.

Since generating the API documentation requires to use :code:`odoc`,
:code:`drom` will automatically install the Development dependencies
of your project. They are usually tools like :code:`merlin`,
:code:`odoc` or :code:`ocamlformat` that only developers will need.

Still, you can trigger directly their installation using::

  $ drom dev-deps
  In opam switch 4.10.0
  Calling opam install odoc ocamlformat
  The following actions will be performed:
    ∗ install odoc        1.5.1
    ∗ install ocamlformat 0.15.0
  ===== ∗ 2 =====
  
  <><> Gathering sources ><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
  [ocamlformat.0.15.0] found in cache
  [odoc.1.5.1] found in cache
  
  <><> Processing actions <><><><><><><><><><><><><><><><><><><><><><><><><><><><>
  ∗ installed odoc.1.5.1
  ∗ installed ocamlformat.0.15.0
  Done.

In our case, only :code:`odoc` and :code:`ocamlformat` have been
detected as missing, so they are installed.

Let's now generate the API documentation::

  $ drom odoc
  In opam switch 4.10.0
  Calling opam exec -- dune build
  Calling opam exec -- dune build @doc
  Calling rsync -auv --delete _build/default/_doc/_html/. _drom/docs/doc
  sending incremental file list
  ./
  highlight.pack.js
  index.html
  odoc.css
  hello_world/
  hello_world/index.html
  
  sent 26,886 bytes  received 103 bytes  53,978.00 bytes/sec
  total size is 26,507  speedup is 0.98

The API documentation has been generated and copied into
:code:`_drom/docs/doc`.

Let's now generate the Sphinx documentation::

  $ drom sphinx
  Calling sphinx-build sphinx _drom/docs/sphinx
  Running Sphinx v1.8.5
  building [mo]: targets for 0 po files that are out of date
  building [html]: targets for 4 source files that are out of date
  updating environment: 4 added, 0 changed, 0 removed

  /tmp/hello_world/sphinx/index.rst:8: WARNING: Title underline too short.

  Welcome to hello_world doc
  =================
  looking for now-outdated files... none found
  pickling environment... done
  checking consistency... done
  preparing documents... done
  writing output... [100%] license
  generating indices... genindex
  writing additional pages... search
  copying static files... done
  copying extra files... done
  dumping search index in English (code: en) ... done
  dumping object inventory... done
  build succeeded, 1 warning.

  The HTML pages are in _drom/docs/sphinx.

We can now check how it looks like::

  $ xdg-open ./_drom/docs/sphinx/index.html

