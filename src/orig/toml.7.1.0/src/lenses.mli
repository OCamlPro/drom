(** Partial lenses (returns [option]) for accessing TOML structures. They make
    it possible to read/write deeply nested immutable values. *)

type ('a, 'b) lens =
  { get : 'a -> 'b option
  ; set : 'b -> 'a -> 'a option
  }

(** Extracts a value from some Toml data using a lens. Returns [Some value] if
    the underlying data matched the lens, or [None].

    Example:

    {[
      utop # let toml_data = Toml.Parser.(from_string "
      [this.is.a.deeply.nested.table]
      answer=42" |> unsafe);;
      val toml_data : Types.table = <abstr>

      utop # Toml.Lenses.(get toml_data (
        key "this" |-- table
        |-- key "is" |-- table
        |-- key "a" |-- table
        |-- key "deeply" |-- table
        |-- key "nested" |-- table
        |-- key "table" |-- table
        |-- key "answer"|-- int ));;
      - : int option = Some 42
    ]}
    @since 4.0.0 *)
val get : 'a -> ('a, 'b) lens -> 'b option

(** Replaces an existing value in some Toml data using a lens. Returns
    [Some value] if the underlying data matched the lens, or [None].

    Example:

    {[
      utop # let toml_data = Toml.Parser.(from_string "
      [this.is.a.deeply.nested.table]
      answer=42" |> unsafe);;
      val toml_data : Types.table = <abstr>

      utop # let maybe_toml_data' = Toml.Lenses.(set 2015 toml_data (
        key "this" |-- table
        |-- key "is" |-- table
        |-- key "a" |-- table
        |-- key "deeply" |-- table
        |-- key "nested" |-- table
        |-- key "table" |-- table
        |-- key "answer"|-- int ));;
      val maybe_toml_data' : Types.table option = Some <abstr>

      utop # let (Some toml_data') = maybe_toml_data';;
      val toml_data' : Types.table = <abstr>

      utop # Toml.Printer.string_of_table toml_data';;
      - : bytes = "[this.is.a.deeply.nested.table]\nanswer = 2015\n"
    ]}
    @since 4.0.0 *)
val set : 'b -> 'a -> ('a, 'b) lens -> 'a option

(** Applies a function on an existing value in some Toml data. Returns
    [Some value] if the underlying data matched the lens, or [None].

    Example:

    {[
      utop # let toml_data = Toml.Parser.(from_string "
        [[table.of.mixed_values]]
        int=0
        str=\"a\"
        [[table.of.mixed_values]]
        str=\"b\"
        [[table.of.mixed_values]]
        int=3
      " |> unsafe);;
      val toml_data : Types.table = <abstr>

      utop # let maybe_toml_data' =  Toml.Lenses.(update
        (fun ts -> Some (
          List.map (fun t ->
            (** Add 'int=42' to each table which doesn't already have an 'int' key *)
            if not (Types.Table.mem (Toml.key "int") t) then
              Types.Table.add (Toml.key "int") (Types.TInt 42) t
            else t) ts))
        toml_data
        (key "table" |-- table
         |-- key "of" |-- table
         |-- key "mixed_values" |-- array |-- tables));;
      val maybe_toml_data' : Types.table option = Some <abstr>

      utop # let (Some toml_data') = maybe_toml_data';;
      val toml_data' : Types.table = <abstr>

      utop # print_endline @@ Toml.Printer.string_of_table toml_data';;

      [[table.of.mixed_values]]
      int = 0
      str = "a"
      [[table.of.mixed_values]]
      int = 42
      str = "b"
      [[table.of.mixed_values]]
      int = 3
      - : unit = ()
    ]}
    @since 4.0.0 *)
val update : ('b -> 'b option) -> 'a -> ('a, 'b) lens -> 'a option

(** Lens composition.

    @since 4.0.0 *)
val compose : ('a, 'b) lens -> ('c, 'a) lens -> ('c, 'b) lens

(** Flipped lens composition.

    @since 4.0.0 *)
val ( |-- ) : ('a, 'b) lens -> ('b, 'c) lens -> ('a, 'c) lens

(** Lens to a particular value in a table.

    @raise Types.Table.Key.Bad_key if the key contains invalid characters.
    @since 4.0.0 *)
val key : string -> (Types.table, Types.value) lens

(** Combines the [key] and [table] lenses, for the common case of nested tables.

    @raise Types.Table.Key.Bad_key if the key contains invalid characters.
    @since 4.0.0 *)
val field : string -> (Types.table, Types.table) lens

(** Lens to a string value.

    @since 4.0.0 *)
val string : (Types.value, string) lens

(** Lens to a boolean value.

    @since 4.0.0 *)
val bool : (Types.value, bool) lens

(** Lens to an int value.

    @since 4.0.0 *)
val int : (Types.value, int) lens

(** Lens to a float value.

    @since 4.0.0 *)
val float : (Types.value, float) lens

(** Lens to a date value.

    @since 4.0.0 *)
val date : (Types.value, float) lens

(** Lens to an array value.

    @since 4.0.0 *)
val array : (Types.value, Types.array) lens

(** Lens to a table value.

    @since 4.0.0 *)
val table : (Types.value, Types.table) lens

(** Lens to an array of strings.

    @since 4.0.0 *)
val strings : (Types.array, string list) lens

(** Lens to an array of booleans.

    @since 4.0.0 *)
val bools : (Types.array, bool list) lens

(** Lens to an array of ints.

    @since 4.0.0 *)
val ints : (Types.array, int list) lens

(** Lens to an array of floats.

    @since 4.0.0 *)
val floats : (Types.array, float list) lens

(** Lens to an array of dates.

    @since 4.0.0 *)
val dates : (Types.array, float list) lens

(** Lens to an array of tables.

    @since 4.0.0 *)
val tables : (Types.array, Types.table list) lens

(** Lens to an array of arrays.

    @since 4.0.0 *)
val arrays : (Types.array, Types.array list) lens
