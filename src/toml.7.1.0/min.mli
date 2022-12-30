(** Turns a string into a table key.

    @raise Types.Table.Key.Bad_key if the key contains invalid characters.
    @since 2.0.0 *)
val key : string -> Types.Table.Key.t

(** Builds a Toml table out of a list of (key, value) tuples.

    @since 4.0.0 *)
val of_key_values : (Types.Table.Key.t * Types.value) list -> Types.table
