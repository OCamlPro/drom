(** Parses raw data into Toml data structures *)

(** The location of an error. The [source] gives the source file of the error.
    The other fields give the location of the error inside the source. They all
    start from one. The [line] is the line number, the [column] is the number of
    characters from the start of the line, and the [position] is the number of
    characters from the start of the source. *)
type location =
  { source : string
  ; line : int
  ; column : int
  ; position : int
  }

(** Parsing result. Either Ok or error (which contains a (message, location)
    tuple). *)
type result =
  [ `Ok of Types.table
  | `Error of string * location
  ]

(** Given a lexer buffer and a source (eg, a filename), returns a [result].

    @raise Toml.Parser.Error if the buffer is not valid Toml.
    @since 2.0.0 *)
val parse : Lexing.lexbuf -> string -> result

(** Given an UTF-8 string, returns a [result].

    @since 2.0.0 *)
val from_string : string -> result

(** Given an input channel, returns a [result].

    @since 2.0.0 *)
val from_channel : in_channel -> result

(** Given a filename, returns a [result].

    @raise Stdlib.Sys_error if the file could not be opened.
    @since 2.0.0 *)
val from_filename : string -> result

exception Error of (string * location)

(** A combinator to force the result. Raise [Error] if the result was [`Error].

    @since 4.0.0 *)
val unsafe : result -> Types.table
