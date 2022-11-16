
How to install
==============

Install with :code:`opam`
-------------------------

If :code:`drom` is available in your opam repository, you can just call::

  opam install drom

Build and install with :code:`dune`
-----------------------------------

Checkout the sources of :code:`drom` in a directory.

You need a switch with at least version :code:`4.07.0` of OCaml,
you can for example create it with::

  opam switch create 4.10.0

Then, you need to install all the dependencies::

  opam install --deps-only .

Finally, you can build the package and install it::

  eval $(opam env)
  dune build
  dune install

Note that a :code:`Makefile` is provided, it contains the following
targets:

* :code:`build`: build the code
* :code:`install`: install the generated files
* :code:`build-deps`: install opam dependencies
* :code:`sphinx`: build sphinx documentation (from the :code:`sphinx/` directory)
* :code:`dev-deps`: build development dependencies, in particular
  :code:`ocamlformat`, :code:`odoc` and :code:`merlin`
* :code:`doc`: build documentation with :code:`odoc`
* :code:`fmt`: format the code using :code:`ocamlformat`
* :code:`test`: run tests

Installing :code:`drom` globally
--------------------------------

There are two recommendend approaches to using `drom` globally.

User profile shell function
^^^^^^^^^^^^^^^^^^^^^^^^^^^

The simplest way to use :code:`drom` globally is through a shell 
function.
::
   function drom () { 
     opam config exec --switch=SWITCH -- drom "$@"; 
   }

The value for :code:`SWITCH` can easily be obtained via 
:code:`opam switch -s show`.

Global binary
^^^^^^^^^^^^^

To be installed globally, :code:`drom` will need to locate its data
files, in particular its skeleton and license files. This files are
usually installed in :code:`$OPAM_SWITCH_PREFIX/share/drom` when
:code:`drom` is installed through :code:`opam`.

Once you have copied :code:`drom` executable in a global location
(:code:`/usr/local/bin/drom` for example), you should do one of these
two actions:

* Set the :code:`DROM_SHARE_DIR` environment variable to the location
  to the share dir containing its files
  (:code:`$HOME/.opam/4.10.0/share/drom` for example if :code:`drom`
  was installed in switch :code:`4.10.0`)

* Edit :code:`$HOME/.config/drom/config` and define the
  :code:`share-dir` option. For example::

          share-dir = "/home/user/.opam/4.10.0/share/drom"

.. note::
  On MacOS the configuration file is can be found in the following location:
  :: 
      $HOME/Library/Application Support/com.ocamlpro.drom/config

Note that you can also copy :code:`drom`'s share directory to a global
location if don't want the files to be removed accidentally by an
:code:`opam` operation.
