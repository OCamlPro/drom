(** Given a Toml value and a formatter, inserts a valid Toml representation of
    this value in the formatter.

    @since 2.0.0 *)
val value : Format.formatter -> Types.value -> unit

(** Given a Toml table and a formatter, inserts a valid Toml representation of
    this value in the formatter.

    @since 2.0.0 *)
val table : Format.formatter -> Types.table -> unit

(** Given a Toml array and a formatter, inserts a valid Toml representation of
    this value in the formatter.

    @raise Invalid_argument if the array is an array of tables
    @since 2.0.0 *)
val array : Format.formatter -> Types.array -> unit

(** Turns a Toml value into a string.

    @since 4.0.0 *)
val string_of_value : Types.value -> string

(** Turns a Toml table into a string.

    @since 4.0.0 *)
val string_of_table : Types.table -> string

(** Turns a Toml array into a string.

    @since 4.0.0 *)
val string_of_array : Types.array -> string
