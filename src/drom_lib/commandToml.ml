(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Ezcmd.V2
open EZCMD.TYPES

let cmd_name = "toml"

let parse_and_print file =
  match Drom_toml.Parser.from_filename file with
  | `Ok toml ->
      let s = Drom_toml.Printer.string_of_table toml in
      Printf.printf "%s%!" s
  | `Error (s, loc) ->
      Error.raise "Could not parse file: %s at %s" s
        (EzToml.string_of_location loc)

let cmd =
  EZCMD.sub cmd_name
    (fun () -> ())
    ~args:[
      [], Arg.Anons (fun files ->
          List.iter parse_and_print files
        ),
      EZCMD.info ~docv:"FILE"
        "Parse FILE and write it back on stdout"
    ]
    ~doc:"Read TOML files and print them back on stdout"
    ~man:
      [ `S "DESCRIPTION";
        `Blocks
          [ `P "Test the TOML parser/printer:" ]
      ]
