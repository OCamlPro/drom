(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

module TYPES = struct
  include TomlTypes

  type 'a encoding =
    { to_toml : 'a -> value;
      of_toml : key:string list -> value -> 'a
    }
end

module EZ = struct
  let key = Toml.key

  let empty = TomlTypes.Table.empty

  let find = TomlTypes.Table.find

  let add = TomlTypes.Table.add

  let to_string = EzTomlPrinter.string_of_table

  let from_file = Toml.Parser.from_filename

  let from_string = Toml.Parser.from_string

  let string_of_location loc = loc.Toml.Parser.source

  let from_file_exn filename =
    match Toml.Parser.from_filename filename with
    | `Ok content -> content
    | `Error (s, loc) ->
      Printf.kprintf failwith "Could not parse %S: %s at %s" filename s
        (string_of_location loc)

  let from_string_exn content =
    match Toml.Parser.from_string content with
    | `Ok content -> content
    | `Error (s, loc) ->
      Printf.kprintf failwith "Could not parse toml content: %s at %s" s
        (string_of_location loc)
end

open TYPES
include EZ

let failwith fmt = Printf.kprintf failwith fmt

let key2str key = String.concat "." key

let iter f table =
  TomlTypes.Table.iter
    (fun key v -> f (TomlTypes.Table.Key.to_string key) v)
    table

let rec get table keys =
  match keys with
  | [] -> assert false
  | [ key ] -> find (Toml.key key) table
  | key :: keys -> (
    match find (Toml.key key) table with
    | exception Not_found -> raise Not_found
    | TTable table2 -> get table2 keys
    | _ ->
      Printf.eprintf "wrong key %s\n%!" key;
      raise Not_found )

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

let get_string_option ?default table keys =
  match get_string table keys with
  | exception Not_found -> default
  | "" -> default
  | s -> Some s

let get_bool table keys =
  match get table keys with
  | TBool s -> s
  | _ -> raise Not_found

let expecting_type expect keys =
  failwith "Error parsing file: key %s should have type %s" (key2str keys)
    expect

let get_bool_option ?default table keys =
  match get table keys with
  | TBool s -> Some s
  | TString "" -> default
  | _ -> expecting_type "bool" keys
  | exception _ -> default

let get_bool_default table keys default =
  match get_bool table keys with
  | exception Not_found -> default
  | s -> s

let rec put keys v table =
  match keys with
  | [] -> assert false
  | [ key ] -> add (Toml.key key) v table
  | key :: keys ->
    let key = Toml.key key in
    let v =
      match find key table with
      | exception Not_found -> put keys v empty
      | TTable table -> put keys v table
      | _ -> assert false
    in
    add key (TTable v) table

let put_string keys s table = put keys (TString s) table

let put_bool keys s table = put keys (TBool s) table

let put_bool_option key bo table =
  match bo with
  | None -> table
  | Some b -> put_bool key b table

let put_option keys so table =
  match so with
  | None -> table
  | Some v -> put_bool keys v table

let put_string_option keys so table =
  match so with
  | None -> table
  | Some s -> put_string keys s table

let encoding ~to_toml ~of_toml = { to_toml; of_toml }

let put_encoding encoding key v table = put key (encoding.to_toml v) table

let put_encoding_option encoding key vo table =
  match vo with
  | None -> table
  | Some v -> put_encoding encoding key v table

let get_encoding encoding table key = encoding.of_toml ~key (get table key)

let get_encoding_default encoding table key default =
  match get table key with
  | exception _ -> default
  | TString "" -> default
  | s -> encoding.of_toml ~key s

let get_encoding_option ?default encoding table key =
  match get table key with
  | exception _ -> default
  | TString "" -> default
  | s -> Some (encoding.of_toml ~key s)

let get_string_list_option ?default table key =
  match get table key with
  | TArray (NodeString v) -> Some v
  | TString "" -> default
  | _ -> failwith "Wrong type for field %S" (key2str key)
  | exception Not_found -> default

let get_string_list_default table key default =
  match get table key with
  | TArray NodeEmpty -> []
  | TArray (NodeString v) -> v
  | TString "" -> default
  | _ -> failwith "Wrong type for field %S" (key2str key)
  | exception Not_found -> default

let put_string_list_option key lo table =
  match lo with
  | None -> table
  | Some l -> put key (TArray (NodeString l)) table

let put_string_list key list table = put key (TArray (NodeString list)) table

let expect_table ~key ~name v =
  match v with
  | TTable table -> table
  | _ -> failwith "wrong type for key %s (%s expected)" (key2str key) name

let expect_string ~key v =
  match v with
  | TString s -> s
  | _ -> failwith "wrong type for key %s (string expected)" (key2str key)

let enum_encoding ~to_string ~of_string =
  encoding
    ~to_toml:(fun v -> TString (to_string v))
    ~of_toml:(fun ~key v ->
      let s = expect_string ~key v in
      of_string ~key s)

let string_encoding =
  encoding
    ~to_toml:(fun v -> TString v)
    ~of_toml:(fun ~key v -> expect_string ~key v)

(* [union table1 table2] merges 2 configurations, with a preference
   for table2 in case of conflict.  Recursive on tables and arrays of
   similar types.  *)

let rec union table1 table2 =
  let table = ref table1 in
  Table.iter
    (fun key v2 ->
      let v =
        match Table.find key table1 with
        | exception Not_found -> v2
        | v1 -> (
          match (v2, v1) with
          | TTable t2, TTable t1 -> TTable (union t1 t2)
          | TArray a2, TArray a1 ->
            TArray
              ( match (a2, a1) with
              | NodeEmpty, a1 -> a1
              | NodeBool a2, NodeBool a1 -> NodeBool (a1 @ a2)
              | NodeInt a2, NodeInt a1 -> NodeInt (a1 @ a2)
              | NodeFloat a2, NodeFloat a1 -> NodeFloat (a1 @ a2)
              | NodeString a2, NodeString a1 -> NodeString (a1 @ a2)
              | NodeDate a2, NodeDate a1 -> NodeDate (a1 @ a2)
              | a2, _ -> a2 )
          | ( ( TBool _ | TInt _ | TFloat _ | TString _ | TDate _ | TTable _
              | TArray _ ),
              _ ) ->
            v2 )
      in
      table := Table.add key v !table)
    table2;
  !table
