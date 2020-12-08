
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

The Skeleton Substitution Language
----------------------------------

Brace Substitutions
~~~~~~~~~~~~~~~~~~~

Paren Substitutions
~~~~~~~~~~~~~~~~~~~

Bracket Substitutions
~~~~~~~~~~~~~~~~~~~~~

Brace Substitutions
-------------------


Project and Package Fields
--------------------------
