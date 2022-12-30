(** Given two Toml values, return [-1], [0] or [1] depending on whether the
    first is smaller, equal or greater than the second

    @since 2.0.0 *)
val value : Types.value -> Types.value -> int

(** Given two Toml arrays, return [-1], [0] or [1] depending on whether the
    first is smaller, equal or greater than the second

    @since 2.0.0 *)
val array : Types.array -> Types.array -> int

(** Given two Toml tables, return [-1], [0] or [1] depending on whether the
    first is smaller, equal or greater than the second

    @since 2.0.0 *)
val table : Types.table -> Types.table -> int
