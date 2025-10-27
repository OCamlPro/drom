open Lexing

type location =
  { source : string
  ; line : int
  ; column : int
  ; position : int
  }

type result =
  [ `Ok of Types.table
  | `Error of string * location
  ]

let parse lexbuf source =
  try
    let result = Menhir_parser.toml Lexer.tomlex lexbuf in
    `Ok result
  with (Menhir_parser.Error | Failure _) as error ->
    let formatted_error_msg =
      match error with
      | Failure failure_msg -> Printf.sprintf ": %s" failure_msg
      | _ -> ""
    in
    let location =
      { source
      ; line = lexbuf.lex_curr_p.pos_lnum
      ; column = lexbuf.lex_curr_p.pos_cnum - lexbuf.lex_curr_p.pos_bol
      ; position = lexbuf.lex_curr_p.pos_cnum
      }
    in
    let msg =
      Printf.sprintf "Error in %s at line %d at column %d (position %d)%s"
        source location.line location.column location.position
        formatted_error_msg
    in
    `Error (msg, location)

let from_string s = parse (Lexing.from_string s) "<string>"

let from_channel c = parse (Lexing.from_channel c) "<channel>"

let from_filename f =
  let c = open_in f in
  let res = parse (Lexing.from_channel c) f in
  close_in c;
  res

exception Error of (string * location)

(** A combinator to force the result. Raise [Error] if the result was [`Ok] *)
let unsafe result =
  match result with
  | `Ok toml_table -> toml_table
  | `Error (msg, location) -> raise (Error (msg, location))
