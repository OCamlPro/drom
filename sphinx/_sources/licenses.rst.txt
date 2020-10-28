
Managing Licenses
=================

:code:`drom` can be used to automatically create license files for
your project, i.e. the :code:`LICENSE.md` file, plus annotations in
the documentation. For that, some licenses have been hardcoded in
:code:`drom`, with specific identifiers. You should use these
identifiers in the :code:`license` field of the :code:`drom.toml`
file. If :code:`drom` does not know the license corresponding to the
identifier, it will default to printing just that name as the license.

To help you, :code:`drom` generates a file
:code:`_drom/known-licences.txt` in your project, containing
associations between these identifiers and SPDX names. Note that, as
all the content of :code:`_drom/`, this file is not to be committed in
your project and will be ignored by :code:`git`.

Here is an example of this file::

  Licenses known by drom:
  * BSD2 -> BSD-2-Clause
  * BSD3 -> BSD-3-Clause
  * GPL3 -> GPL-3.0-only
  * ISC -> ISC
  * LGPL2 -> LGPL-2.1-with-OCaml-exception
  * MIT -> MIT

By default, :code:`drom` will use the identifier :code:`LGPL2`,
corresponding to the historic license of OCaml.

