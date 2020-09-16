
User Configuration
==================

:code:`drom` will extract some information from the environement, from
both configuration files and environement variables.

Configuration Files
-------------------

:code:`drom` uses a configuration file for some user-specific
information.  The configuration file is search in 2 locations:

* In :code:`$HOME/.config/drom/config` first
* In :code:`$HOME/.drom/config` otherwise

If no configuration file is found, :code:`drom` will generate the
following template in :code:`.config/drom/config`::

  [user]
  # author = "Author Name <email>"
  # github-organization = "...organization..."
  # license = "...license..."
  # copyright = "Company Ltd"
  # opam-repo = "/home/user/GIT/opam-repository"

These fields are used as default values when calling
:code:`drom`. Most of them are used by :code:`drom project`, except
:code:`opam-repo` which is used by :code:`drom publish` to find an
opam repository where to save new project descriptions.

If the :code:`author` field is not specified, :code:`drom` will try to
compute it from :code:`git` configuration file in
:code:`$HOME/.gitconfig`.

Environment Variables
---------------------

The following environment variables will take precedence over the
values found in :code:`drom` configuration file:

* :code:`DROM_AUTHOR` overrides :code:`author`
* :code:`DROM_GITHUB_ORGANIZATION` overrides :code:`github-organization`
* :code:`DROM_LICENSE` overrides :code:`license`
* :code:`DROM_COPYRIGHT` overrides :code:`copyright`
* :code:`DROM_OPAM_REPO` overrides :code:`opam-repo`

The following environment variables are used to compute the
:code:`author` field if not found:

* For the name:

  * :code:`DROM_USER`
  * :code:`GIT_AUTHOR_NAME`
  * :code:`GIT_COMMITTER_NAME`
  * from :code:`git` configuration file
  * :code:`USER`
  * :code:`USERNAME`
  * :code:`NAME`

* For the email:

  * :code:`DROM_EMAIL`
  * :code:`GIT_AUTHOR_EMAIL`
  * :code:`GIT_COMMITTER_EMAIL`
  * from :code:`git` configuration file
