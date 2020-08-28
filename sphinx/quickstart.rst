
Quickstart
==========

General Purpose
---------------

:code:`drom` has two purposes:

* It's a tool to easily create OCaml projects: :code:`drom new
  PROJECT` will create a complete OCaml project, with all the required
  files for :code:`opam` and :code:`dune`, plus additional files for
  documentation (Sphinx and Github Pages) and CI (Github Actions).

* It's a tool to build and install the project, combining calls to
  `opam` and `dune` to create a local switch, install dependencies,
  build the project and its documentation

Creating a Project with :code:`drom`
------------------------------------

Let's suppose we want to create a new project :code:`hello_world`. We
can use `drom` to create almost everything we need for that!

Let's create the project::

  $ drom new hello_world
  Loading config from /home/user/.config/drom
  Creating directory hello_world
  Creating file drom.toml
  Creating file .gitignore
  Creating file Makefile
  Creating file README.md
  Creating file src/dune
  Creating file src/main.ml
  Creating file CHANGES.md
  Calling git init
  Initialized empty Git repository in /tmp/hello_world/.git/
  Calling git add README.md
  Calling git commit -m Initial commit
  [master (root-commit) 7fef447] Initial commit
  1 file changed, 14 insertions(+)
  create mode 100644 README.md
  Creating file docs/index.html
  Creating file docs/style.css
  Creating file docs/doc/index.html
  Creating file docs/sphinx/index.html
  Creating file docs/.nojekyll
  Creating file sphinx/conf.py
  Creating file sphinx/index.rst
  Creating file sphinx/install.rst
  Creating file sphinx/license.rst
  Creating file sphinx/about.rst
  Creating file sphinx/_static/css/fixes.css
  Creating file dune-project
  Creating file .ocamlformat
  Creating file .github/workflows/ci.ml
  Creating file .github/workflows/workflow.yml
  Creating file hello_world.opam
  Creating file LICENSE.md
  Calling git add .drom LICENSE.md hello_world.opam .github/workflows/workflow.yml .github/workflows/ci.ml .ocamlformat dune-project sphinx/_static/css/fixes.css sphinx/about.rst sphinx/license.rst sphinx/install.rst sphinx/index.rst sphinx/conf.py docs/.nojekyll docs/sphinx/index.html docs/doc/index.html docs/style.css docs/index.html CHANGES.md src/main.ml src/dune README.md Makefile .gitignore drom.toml

As you can see, :code:`drom` created a directory :code:`hello_world`
with the following files:

* :code:`drom.toml` for project management by :code:`drom`
* :code:`.gitignore` and :code:`.git/` for the :code:`git` revision
  control tool
* :code:`docs/index.html` and :code:`docs/style.css` for the project
  homepage
* :code:`sphinx/` directory for the Sphinx documentation formatter
* :code:`README.md`, `CHANGES.md` and `LICENSE.md` project files
* :code:`src/main.ml` code example
* :code:`dune-project`, :code:`hello_world.opam` and `src/dune` for the
  :code:`dune` build tool
* :code:`.github/` for Github Actions CI
* :code:`.ocamlformat` for the :code:`ocamlformat` code formatting tool

At this point, you may decide that :code:`drom` has done enough for
you, and you can go back to using :code:`opam` and :code:`dune` to
work on your project.
  
The :code:`drom.toml` file has a particular importance, it can be used
by :code:`drom` to update all the generated files with this
information. It contains information on the project, such as its name,
license, description, dependencies, etc.

Everytime you modify :code:`drom.toml`, you should call :code:`drom
new` again to update the project::

  $ cd hello_world
  $ emacs drom.toml
  $ drom new
  Loading config from /home/user/.drom/config
  Loading drom.toml
  Loading .drom
  Updating file src/dune
  Updating file dune-project
  Updating file hello_world.opam
  Calling git add .drom hello_world.opam dune-project src/dune

Here, we added a dependency in the `drom.toml` file::

  ...
  [dependencies]
  ez_file = "0.1.0"
  ...

And we see that :code:`drom` updated the files :code:`src/dune`,
:code:`dune-project` and :code:`hello_world.opam`.

:code:`drom new` also takes a few command line options that can be
used to modify the :code:`drom.toml` file:

* :code:`--upgrade` can be used to upgrade the :code:`drom.toml` file
  when you are using a more recent version of :code:`drom`
* :code:`--binary` and :code:`--javascript` can be used to switch between
  generating binaries and generating Javascript using
  :code:`js_of_ocaml`.
* :code:`--program`, :code:`--library` and :code:`--both` can be used
  to switch between building a program, a library or both.

Notice that, just after creating the project, you should be able to
build it and run it with no error!

Building a Project with :code:`drom`
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
  Loading drom.toml
  Loading .drom
  Loading config from /home/user/.config/drom/config
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
  Loading drom.toml
  Loading .drom
  Loading config from /home/user/.config/drom/config
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
  Loading drom.toml
  Loading .drom
  Loading config from /home/user/.config/drom/config
  Error: You must remove the local switch `_opam` before using option --switch

Since we previously built the project locally, we have a local
:code:`_opam` switch. :code:`drom` will not remove this switch
automatically, because it is often long to rebuild. So, you will have
to do it yourself (or backup it if you are not using
:code:`opam-bin`)::

  $ rm -rf _opam
  $ drom build --switch 4.10.0
  Loading drom.toml
  Loading .drom
  Loading config from /home/user/.config/drom/config
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
  Loading drom.toml
  Loading .drom
  Loading config from /home/user/.config/drom/config
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

  
