
Use Cases
=========

This sections describes how the handle common use cases with :code:`drom`.


Using :code:`menhir`
--------------------

Whereas :code:`ocamlyacc` is the legacy parser generator for OCaml,
:code:`menhir` is much more powerful and probably more prevalent nowadays.

For trivial usage where there is a simple :code:`parser.mly` file in your
package, setting::

  generators = ["menhir"]

into the corresponding :code:`package.toml` will likely work. However, if
you have multiple :code:`.mly` files, or
need to specify custom :code:`menhir` flags, you'll probably need to use the
:code:`[menhir]` table in the corresponding :code:`package.toml`. For example::

  [menhir]
  version = "2.1"
  parser = {
    modules = ["tokens", "parser"],
    merge-into = "parser",
    tokens = "Tokens",
    flags = [ "--table" ],
    infer = true
  }
  tokens = {
    modules = ["tokens"],
    #flags = []
  }


This will generate the following rules in you :code:`dune` file::

  (menhir
    (modules tokens)
    (flags --only-tokens))
  (menhir
    (modules tokens parser)
    (merge_into parser)
    (flags --table --external-tokens Tokens)
    (infer true))

and will add::

  (using menhir 2.1)

to the :code:`dune-project` file.

You can also can tune the :code:`dune` generation. A good way to properly do that is to disable
the default :code:`dune` generation for and add your own :code:`dune` stanzas
for parsing generators. First, add :code:`(using menhir X.Y)` in the 
:code:`drom.toml`'s ':code:`dune-project-header` field. For example::

  [fields]
  dune-project-header = "(using menhir 2.1)"

Then split your parsing code into at least two files :code:`tokens.mly` and
:code:`parser.mly`. The first one will contain the tokens definitions and the
second one the parsing rules. Doing this allows to parametrize the parser in
a modular fashion by using the :code:`%parameter <>` directive, if needed.
Then replace the :code:`generators = ["menhir"]` line by the following::

  generators = []

in :code:`package.toml` to disable the default :code:`dune` stanzas generation.
Finally, add the following :code:`dune` stanzas to your
:code:`dune-trailer` field::

  [fields]
  dune-trailer = """
  (menhir
    (modules tokens)
    (flags --only-tokens)
  )

  (menhir
    (modules tokens parser)
    (merge_into parser)
    (flags --external-tokens Tokens)
  )
  """

Of course, this is just a basic tuning and you can modify the flags or
targets as needed. The overall result will likely fit in most
of :code:`menhir` usages in :code:`drom` projects waiting for a better
:code:`menhir` support.
