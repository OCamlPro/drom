# toml [![build status](https://github.com/ocaml-toml/to.ml/workflows/build/badge.svg)](https://github.com/ocaml-toml/to.ml/actions) [![coverage percentage](https://raw.githubusercontent.com/ocaml-toml/To.ml/gh-pages/coverage/badge.svg)](https://ocaml-toml.github.io/To.ml/coverage/)

[OCaml] library for [TOML].

## Documentation

Have a look at the [online documentation]. Otherwise, here's a quickstart guide.

### Reading TOML data

```ocaml
# (* This will return either `Ok $tomltable or `Error $error_with_location *)
  let ok_or_error = Toml.Parser.from_string "key=[1,2]";;
val ok_or_error : Toml.Parser.result = `Ok <abstr>

# (* You can use the 'unsafe' combinator to get the result directly, or an
  exception if a parsing error occurred *)
  let parsed_toml = Toml.Parser.(from_string "key=[1,2]" |> unsafe);;
val parsed_toml : Toml.Types.table = <abstr>

# (* Use simple pattern matching to read the value *)
  Toml.Types.Table.find (Toml.Min.key "key") parsed_toml;;
- : Toml.Types.value = Toml.Types.TArray (Toml.Types.NodeInt [1; 2])
```

### Writing TOML data

```ocaml
# let toml_data = Toml.Min.of_key_values [
    Toml.Min.key "ints", Toml.Types.TArray (Toml.Types.NodeInt [1; 2]);
    Toml.Min.key "string", Toml.Types.TString "string value";
  ];;
val toml_data : Toml.Types.table = <abstr>

# Toml.Printer.string_of_table toml_data;;
- : string = "ints = [1, 2]\nstring = \"string value\"\n"
```

### Lenses

Through lenses, it is possible to read/write deeply nested data with ease.
The `Toml.Lenses` module provides partial lenses (that is, lenses returning
`option` types) to manipulate TOML data structures.

```ocaml
# let toml_data = Toml.Parser.(from_string
    "[this.is.a.deeply.nested.table] answer=42" |> unsafe);;
val toml_data : Toml.Types.table = <abstr>

# Toml.Lenses.(get toml_data (
    key "this" |-- table
    |-- key "is" |-- table
    |-- key "a" |-- table
    |-- key "deeply" |-- table
    |-- key "nested" |-- table
    |-- key "table" |-- table
    |-- key "answer"|-- int ));;
- : int option = Some 42

# let maybe_toml_data' = Toml.Lenses.(set 2015 toml_data (
    key "this" |-- table
    |-- key "is" |-- table
    |-- key "a" |-- table
    |-- key "deeply" |-- table
    |-- key "nested" |-- table
    |-- key "table" |-- table
    |-- key "answer"|-- int ));;
val maybe_toml_data' : Toml.Types.table option = Some <abstr>

# Toml.Printer.string_of_table (Option.get maybe_toml_data');;
- : string = "[this.is.a.deeply.nested.table]\nanswer = 2015\n"
```

## Limitations

* Keys don't quite follow the TOML standard. Both section keys (eg,
`[key1.key2]`) and ordinary keys (`key=...`) may not contain the
following characters: space, `\t`, `\n`, `\r`, `.`, `[`, `]`, `"` and `#`.

## Projects using `toml`

- [drom]
- [hll]
- [pds]
- [snabela]
- [soupault]

If you want to add your project, feel free to open a PR.

[drom]: https://ocamlpro.github.io/drom
[hll]: https://hg.sr.ht/~mmatalka/hll
[OCaml]: https://ocaml.org
[online documentation]: https://ocaml-toml.github.io/To.ml
[pds]: https://hg.sr.ht/~mmatalka/pds
[snabela]: https://bitbucket.org/acslab/snabela
[soupault]: https://soupault.neocities.org
[TOML]: https://toml.io
