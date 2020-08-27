
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
  Loading config from /home/lefessan/.drom/config
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

:code:`drom` can be used to build a
