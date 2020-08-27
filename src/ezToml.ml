(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

module TYPES = TomlTypes

module EZ = struct

  let key = Toml.key
  let empty = TomlTypes.Table.empty
  let find = TomlTypes.Table.find
  let add = TomlTypes.Table.add

  let to_string = EzTomlPrinter.string_of_table
  let from_file = Toml.Parser.from_filename

end

open TYPES
include EZ

let rec get table keys =
  match keys with
  | [] -> assert false
  | [ key ] ->
    find (Toml.key key ) table
  | key :: keys ->
    match find ( Toml.key key) table with
    | exception Not_found ->
      raise Not_found
    | TTable table2 -> get table2 keys
    | _ ->
      Printf.eprintf "wrong key %s\n%!" key;
      raise Not_found

let get_string table keys =
  match get table keys with
  | TString s -> s
  | _ -> raise Not_found
  | exception _exn ->
    (*
    Printf.eprintf "Missing key %s: exception %s in %s\n%!"
      ( String.concat "." keys )
      ( Printexc.to_string exn )
      ( Toml.Printer.string_of_table table )
    ; *)
    raise Not_found

let get_string_default table keys default =
  match get_string table keys with
  | exception Not_found -> default
  | s -> s

let get_string_option table keys =
  match get_string table keys with
  | exception Not_found -> None
  | s -> Some s

let get_bool table keys =
  match get table keys with
  | TBool s -> s
  | _ -> raise Not_found

let expecting_type expect keys =
  Error.raise
    "Error parsing file: key %s should have type %s"
    ( String.concat "." keys ) expect

let get_bool_option table keys =
  match get table keys with
  | TBool s -> Some s
  | _ -> expecting_type "bool" keys
  | exception _ -> None

let get_bool_default table keys default =
  match get_bool table keys with
  | exception Not_found -> default
  | s -> s

let rec put keys v table =
  match keys with
  | [] -> assert false
  | [ key ] -> add ( Toml.key key ) v table
  | key :: keys ->
    let key = Toml.key key in
    let v =
      match find key table with
      | exception Not_found -> put keys v empty
      | TTable table ->
        put keys v table
      | _ ->
        assert false
    in
    add key ( TTable v ) table

let put_string keys s table =
  put keys ( TString s ) table

let put_bool keys s table =
  put keys ( TBool s ) table

let put_string_option keys so table =
  match so with
  | None -> table
  | Some s ->
    put_string keys s table

type 'a encoding = {
  to_toml : ( 'a -> string ) ;
  of_toml : ( string -> 'a ) ;
}

let encoding ~to_toml ~of_toml = { to_toml ; of_toml }

let put_encoding encoding key v table =
  put_string key (encoding.to_toml v) table

let get_encoding encoding table key =
  encoding.of_toml ( get_string key table )

let get_encoding_default encoding table key default =
  match get_string table key with
  | exception _ -> default
  | s -> encoding.of_toml s
