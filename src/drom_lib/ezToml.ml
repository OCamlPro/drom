(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open EzCompat

module TYPES = struct
  include Toml.Types

  type 'a encoding =
    { to_toml : 'a -> value;
      of_toml : key:string list -> value -> 'a
    }
end

module EZ = struct
  let key = Toml.Min.key

  let empty = Toml.Types.Table.empty

  let find = Toml.Types.Table.find

  let add = Toml.Types.Table.add

  let to_string = Toml.Printer.string_of_table

  let from_file = Toml.Parser.from_filename

  let from_string = Toml.Parser.from_string

  let map = Toml.Types.Table.map

  let string_of_location loc = loc.Toml.Parser.source

  let from_file_exn filename =
    match Toml.Parser.from_filename filename with
    | `Ok content -> content
    | `Error (s, loc) ->
      Printf.ksprintf failwith "Could not parse %S: %s at %s" filename s
        (string_of_location loc)

  let from_string_exn content =
    match Toml.Parser.from_string content with
    | `Ok content -> content
    | `Error (s, loc) ->
      Printf.ksprintf failwith "Could not parse toml content: %s at %s" s
        (string_of_location loc)
end

open TYPES
include EZ

let failwith fmt = Printf.ksprintf failwith fmt

let key2str key = String.concat "." key

let iter f table =
  Toml.Types.Table.iter
    (fun key v -> f (Toml.Types.Table.Key.to_string key) v)
    table

let rec get table keys =
  match keys with
  | [] -> assert false
  | [ key ] -> find (Toml.Min.key key) table
  | key :: keys -> (
    match find (Toml.Min.key key) table with
    | exception Not_found -> raise Not_found
    | TTable table2 -> get table2 keys
    | _ ->
      Printf.eprintf "wrong key %s\n%!" key;
      raise Not_found )

let get_string table keys =
  match get table keys with
  | TString s -> s
  | _ ->
    failwith "Wrong key type %s: expexted String in %s" (String.concat "." keys)
      (Toml.Printer.string_of_table table)
  | exception _exn -> raise Not_found

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

let get_int table keys =
  match get table keys with
  | TInt i -> i
  | _ -> raise Not_found

let get_int_default table keys default =
  match get_int table keys with
  | exception Not_found -> default
  | i -> i

let rec put keys v table =
  match keys with
  | [] -> assert false
  | [ key ] -> add (Toml.Min.key key) v table
  | key :: keys ->
    let key = Toml.Min.key key in
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
  | TString s -> Some [ s ]
  | _ -> failwith "Wrong type for field %S" (key2str key)
  | exception Not_found -> default

let get_string_list_default table key default =
  match get table key with
  | TArray NodeEmpty -> []
  | TArray (NodeString v) -> v
  | TString "" -> default
  | TString s -> [ s ]
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

let expect_string_list ~key v =
  match v with
  | TArray (NodeString v) -> v
  | TString v -> [ v ]
  | _ -> failwith "wrong type for key %s (string list expected)" (key2str key)

let expect_bool ~key v =
  match v with
  | TBool b -> b
  | _ -> failwith "wrong type for key %s (bool expected)" (key2str key)

let enum_encoding ~to_string ~of_string =
  encoding
    ~to_toml:(fun v -> TString (to_string v))
    ~of_toml:(fun ~key v ->
      let s = expect_string ~key v in
      of_string ~key s )

let string_encoding =
  encoding
    ~to_toml:(fun v -> TString v)
    ~of_toml:(fun ~key v -> expect_string ~key v)

(* [union table1 table2] merges 2 configurations, with a preference
   for table2 in case of conflict.  Recursive on tables and arrays of
   similar types. *)

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
      table := Table.add key v !table )
    table2;
  !table

module ENCODING = struct
  let stringMap enc =
    encoding
      ~to_toml:(fun map ->
        let table = ref empty in
        StringMap.iter
          (fun name s -> table := put [ name ] (enc.to_toml s) !table)
          map;
        TTable !table )
      ~of_toml:(fun ~key v ->
        let table = expect_table ~key ~name:"profile" v in
        let map = ref StringMap.empty in
        iter
          (fun k v ->
            map := StringMap.add k (enc.of_toml ~key:(key @ [ k ]) v) !map )
          table;
        !map )
end

type file_option =
  { option_name : string;
    option_value : Toml.Types.value option;
    option_comment : string list option;
    option_default : string option
  }

type file = { mutable options : file_option list }

let new_file () = { options = [] }

let add file options = file.options <- file.options @ options

let string_of_file file =
  let b = Buffer.create 1000 in
  List.iter
    (fun o ->
      ( match o.option_comment with
      | None -> ()
      | Some s -> Printf.bprintf b "\n# %s\n" (String.concat "\n#" s) );
      Buffer.add_string b
        ( match o.option_value with
        | Some v -> begin
          match v with
          | TTable x when Table.is_empty x ->
            Printf.sprintf "[%s]\n# ...\n" o.option_name
          | _ -> empty |> put [ o.option_name ] v |> to_string
        end
        | None -> (
          match o.option_default with
          | Some s -> Printf.sprintf "# %s\n" s
          | None -> Printf.sprintf "# %s = ...\n" o.option_name ) ) )
    file.options;
  Buffer.contents b

module CONST = struct
  let string s = Some (TString s)

  let string_option = function
    | None -> None
    | Some s -> string s

  let string_list l = Some (TArray (NodeString l))

  let string_list_option = function
    | None -> None
    | Some l -> string_list l

  let encoding enc v = Some (enc.to_toml v)

  let encoding_option enc = function
    | None -> None
    | Some b -> encoding enc b

  let bool b = Some (TBool b)

  let bool_option = function
    | None -> None
    | Some b -> bool b

  let option option_name ?comment ?default option_value =
    { option_name;
      option_value;
      option_comment = comment;
      option_default = default
    }

  let s_ ?section options =
    let file = new_file () in
    add file options;
    let s = string_of_file file in
    match section with
    | None -> s
    | Some section -> Printf.sprintf "[%s]\n%s" section s
end
