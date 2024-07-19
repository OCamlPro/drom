(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open EzToml.TYPES
open Types
open EzCompat
open Ez_file.V1
open EzFile.OP

let create ~name ~dir ~kind = { Globals.dummy_package with name; dir; kind }

let kind_encoding =
  EzToml.enum_encoding
    ~to_string:(function
      | Virtual -> "virtual"
      | Library -> "library"
      | Program -> "program" )
    ~of_string:(fun ~key:_ s ->
      match s with
      | "lib"
      | "library" ->
        Library
      | "program"
      | "executable"
      | "exe" ->
        Program
      | "meta"
      | "virtual" ->
        Virtual
      | kind ->
        Error.raise {|unknown kind %S (should be "library" or "program")|} kind
      )

let string_of_versions versions =
  String.concat " "
    (List.map
       (function
         | Version -> "version"
         | NoVersion -> ""
         | Semantic (major, minor, fix) ->
           Printf.sprintf "%d.%d.%d" major minor fix
         | Lt version -> Printf.sprintf "<%s" version
         | Le version -> Printf.sprintf "<=%s" version
         | Eq version -> Printf.sprintf "=%s" version
         | Ge version -> Printf.sprintf ">=%s" version
         | Gt version -> Printf.sprintf ">%s" version )
       versions )

let versions_of_string versions =
  List.map
    (fun version ->
      match Misc.semantic_version version with
      | Some (major, minor, fix) -> Semantic (major, minor, fix)
      | None -> (
        if version = "" then
          NoVersion
        else if version = "version" then
          Version
        else
          let len = String.length version in
          match version.[0] with
          | '=' -> Eq (String.sub version 1 (len - 1))
          | '<' ->
            if len > 1 && version.[1] = '=' then
              Le (String.sub version 2 (len - 2))
            else
              Lt (String.sub version 1 (len - 1))
          | '>' ->
            if len > 1 && version.[1] = '=' then
              Ge (String.sub version 2 (len - 2))
            else
              Gt (String.sub version 1 (len - 1))
          | _ -> Ge version ) )
    (EzString.split_simplify versions ' ')

let skip_encoding =
  let to_toml list =
    match list with
    | [] -> TArray NodeEmpty
    | list -> TArray (NodeString list)
  in
  let of_toml ~key value =
    match value with
    | TArray NodeEmpty -> []
    | TArray (NodeString v) -> v
    | TString s -> EzString.split s ' '
    | _ -> EzToml.failwith "Wrong type for field %S" (EzToml.key2str key)
  in
  EzToml.encoding ~to_toml ~of_toml

let dependency_encoding =
  EzToml.encoding
    ~to_toml:(fun d ->
      let version = TString (string_of_versions d.depversions) in

      if
        { d with depversions = [] }
        = { depversions = [];
            depname = None;
            deptest = false;
            depdoc = false;
            depopt = false;
            dep_pin = None;
          }
      then
        version
      else
        let table = EzToml.empty in
        let table = EzToml.put_string_option [ "libname" ] d.depname table in
        let table = EzToml.put_string_option [ "pin" ] d.dep_pin table in
        let table =
          match d.depversions with
          | [] -> table
          | _ -> EzToml.put [ "version" ] version table
        in
        let table =
          if d.deptest then
            EzToml.put [ "for-test" ] (TBool true) table
          else
            table
        in
        let table =
          if d.depdoc then
            EzToml.put [ "for-doc" ] (TBool true) table
          else
            table
        in
        let table =
          if d.depopt then
            EzToml.put [ "opt" ] (TBool true) table
          else
            table
        in
        TTable table )
    ~of_toml:(fun ~key v ->
      match v with
      | TString s ->
        let depversions = versions_of_string s in
        { depname = None;
          depversions;
          depdoc = false;
          deptest = false;
          depopt = false;
          dep_pin = None;
        }
      | TTable table ->
        let depname = EzToml.get_string_option table [ "libname" ] in
        let dep_pin = EzToml.get_string_option table [ "pin" ] in
        let depversions = EzToml.get_string_default table [ "version" ] "" in
        let depversions = versions_of_string depversions in
        let deptest = EzToml.get_bool_default table [ "for-test" ] false in
        let depdoc = EzToml.get_bool_default table [ "for-doc" ] false in
        let depopt = EzToml.get_bool_default table [ "opt" ] false in
        { depname; depversions; depdoc; deptest; depopt; dep_pin; }
      | _ -> Error.raise "Bad dependency version for %s" (EzToml.key2str key) )

let dependencies_encoding =
  EzToml.encoding
    ~to_toml:(fun deps ->
      let table =
        List.fold_left
          (fun table (name, d) ->
            EzToml.put_encoding dependency_encoding [ name ] d table )
          EzToml.empty deps
      in
      TTable table )
    ~of_toml:(fun ~key v ->
      let deps = EzToml.expect_table ~key ~name:"dependency list" v in
      let dependencies = ref [] in
      Table.iter
        (fun name _version ->
          let name = Table.Key.to_string name in
          let d = EzToml.get_encoding dependency_encoding deps [ name ] in
          dependencies := (name, d) :: !dependencies )
        deps;
      !dependencies )

let stringSet_encoding =
  EzToml.encoding
    ~to_toml:(fun set -> TArray (NodeString (StringSet.to_list set)))
    ~of_toml:(fun ~key v ->
      match v with
      | TArray NodeEmpty -> StringSet.empty
      | TArray (NodeString list) -> StringSet.of_list list
      | _ -> EzToml.expecting_type "string list" key )

let fields_encoding = EzToml.ENCODING.stringMap EzToml.string_encoding

let menhir_parser_encoding =
  EzToml.encoding
    ~to_toml:(fun { modules; tokens; merge_into; flags; infer } ->
        let table = EzToml.empty
                    |> EzToml.put_string_list [ "modules" ] modules
                    |> EzToml.put_string_option [ "tokens" ] tokens
                    |> EzToml.put_string_option [ "merge-into" ] merge_into
                    |> EzToml.put_string_list_option [ "flags" ] flags
                    |> EzToml.put_bool_option [ "infer" ] infer
        in
        TTable table)
    ~of_toml:(fun ~key v ->
      match v with
        | TTable table ->
            let modules = EzToml.get_string_list_default table [ "modules" ] [ "parser" ] in
            let tokens = EzToml.get_string_option table [ "tokens" ] in
            let merge_into = EzToml.get_string_option table [ "merge-into" ] in
            let flags = EzToml.get_string_list_option table [ "flags" ] in
            let infer = EzToml.get_bool_option table [ "infer" ] in
            { modules; tokens; merge_into; flags; infer; }
        | _ ->
            EzToml.expecting_type "table" key)

let menhir_tokens_encoding =
  EzToml.encoding
    ~to_toml:(fun { modules; flags } ->
        let table = EzToml.empty
                    |> EzToml.put_string_list [ "modules" ] modules
                    |> EzToml.put_string_list_option [ "flags" ] flags
        in
      TTable table)
    ~of_toml:(fun ~key v ->
        match v with
        | TTable table ->
            let modules = EzToml.get_string_list_default table [ "modules"] [ "tokens" ] in
            let flags = EzToml.get_string_list_option table [ "flags" ] in
            { modules; flags }
        | _ ->
            EzToml.expecting_type "table" key)

let menhir_encoding =
  EzToml.encoding
    ~to_toml:(fun { version; parser; tokens } ->
        let table = EzToml.empty
                    |> EzToml.put_string [ "version" ] version
                    |> EzToml.put_encoding menhir_parser_encoding [ "parser" ] parser
                    |> EzToml.put_encoding_option menhir_tokens_encoding [ "encoding" ] tokens
        in
        TTable table)
    ~of_toml:(fun ~key v ->
        match v with
        | TTable table ->
            let version = EzToml.get_string table [ "version" ] in
            let parser = EzToml.get_encoding menhir_parser_encoding table [ "parser" ] in
            let tokens = EzToml.get_encoding_option menhir_tokens_encoding table [ "tokens" ] in
            { version; parser; tokens; }
        | _ ->
            EzToml.expecting_type "talbe" key)

let to_string pk =
  EzToml.CONST.(
    s_
      [ option "name" ~comment:[ "name of package" ] (string pk.name);
        option "skeleton" (string_option pk.p_skeleton);
        option "version"
          ~comment:[ "version if different from project version" ]
          ~default:{|version = "0.1.0"|}
          (string_option pk.p_version);
        option "synopsis"
          ~comment:[ "synopsis if different from project synopsis" ]
          (string_option pk.p_synopsis);
        option "description"
          ~comment:[ "description if different from project description" ]
          (string_option pk.p_description);
        option "kind"
          ~comment:[ {|kind is either "library", "program" or "virtual"|} ]
          (encoding kind_encoding pk.kind);
        option "authors"
          ~comment:[ "authors if different from project authors" ]
          ~default:{|authors = [ "Me <me@metoo.org>" ]|}
          (string_list_option pk.p_authors);
        option "gen-version"
          ~comment:[ "name of a file to generate with the current version" ]
          ~default:{|gen-version = "version.ml"|}
          (string_option pk.p_gen_version);
        option "generators"
          ~comment:
            [ {|supported file generators are "ocamllex", "ocamlyacc" and "menhir" |};
              {| default is [ "ocamllex", "ocamlyacc" ] |}
            ]
          ~default:{|generators = [ "ocamllex", "menhir" ]|}
          (encoding_option stringSet_encoding pk.p_generators);
        option "menhir"
          ~comment:
            [ "menhir options for the package";
              "Example:";
              {|version = "2.0"|};
              {|parser = { modules = ["parser"]; tokens = "Tokens" }|};
              {|tokens = { modules = ["tokens"]}|};
            ]
          (encoding_option menhir_encoding pk.p_menhir);
        option "pack-modules"
          ~comment:
            [ "whether all modules should be packed/wrapped (default is true)" ]
          ~default:{|pack-modules = false|}
          (bool_option pk.p_pack_modules);
        option "optional"
          ~comment:
            [ "whether the package can be silently skipped if missing deps \
               (default is false)"
            ]
          ~default:{|optional = true|}
          (bool_option pk.p_optional);
        option "pack"
          ~comment:
            [ "module name used to pack modules (if pack-modules is true)" ]
          ~default:{|pack = "Mylib"|} (string_option pk.p_pack);
        option "preprocess"
          ~comment:
            [ "preprocessing options";
              {|  preprocess = "per-module (((action (run ./toto.sh %{input-file})) mod))" |}
            ]
          ~default:{|preprocess = "pps ppx_deriving_encoding"|}
          (string_option pk.p_preprocess);
        option "skip"
          ~comment:[ "files to skip while updating at package level" ]
          ~default:{|skip = []|}
          (string_list_option pk.p_skip);
        option "dependencies"
          ~comment:
            [ "package library dependencies";
              "   [dependencies]";
              {|   ez_file = ">=0.1 <1.3"|};
              {|   base-unix = { libname = "unix", version = ">=base" } |}
            ]
          (encoding dependencies_encoding pk.p_dependencies);
        option "tools"
          ~comment:[ "package tools dependencies" ]
          (encoding dependencies_encoding pk.p_tools);
        option "fields"
          ~comment:
            [ "package fields (depends on package skeleton)";
              "Examples:";
              {|  dune-stanzas = "(preprocess (pps ppx_deriving_encoding))" |};
              {|  dune-libraries = "bigstring" |};
              {|  dune-trailer = "(install (..))" |};
              {|  opam-trailer = "pin-depends: [..]" |};
              {|  no-opam-test = "yes" |};
              {|  no-opam-doc = "yes" |};
              {|  gen-opam = "some" | "all" |};
              {|  static-clibs = "unix" |};
            ]
          (encoding fields_encoding pk.p_fields)
      ] )

let find ?default name =
  let defaults =
    match default with
    | None -> []
    | Some p -> p.packages
  in
  let rec iter defaults =
    match defaults with
    | [] -> { Globals.dummy_package with name; dir = "src" // name }
    | package :: defaults ->
      if package.name = name then
        package
      else
        iter defaults
  in
  iter defaults

let of_toml ?default ?p_file table =
  let dir = EzToml.get_string_option table [ "dir" ] in
  let name =
    try EzToml.get_string table [ "name" ] with
    | Not_found ->
      ( match dir with
      | Some dir_path ->
        let package_path = dir_path // "package.toml" in
        if Sys.file_exists package_path then
          Printf.eprintf "Error: Missing field 'name' in %s\n%!" package_path
        else
          Printf.eprintf "Error: %s is missing \n%!" package_path
      | None ->
        Printf.eprintf
          "Error: Missing field 'name' for a package in drom.toml\n%!" );
      exit 2
  in
  let default = find ?default name in
  let dir = Misc.option_value dir ~default:default.dir in
  let kind =
    EzToml.get_encoding_default kind_encoding table [ "kind" ] default.kind
  in
  let project = Globals.dummy_project in
  let p_pack =
    EzToml.get_string_option table [ "pack" ] ?default:default.p_pack
  in
  let p_preprocess =
    EzToml.get_string_option table [ "preprocess" ] ?default:default.p_pack
  in
  let p_version =
    EzToml.get_string_option table [ "version" ] ?default:default.p_version
  in
  let p_authors =
    EzToml.get_string_list_option table [ "authors" ] ?default:default.p_authors
  in
  let p_synopsis =
    EzToml.get_string_option table [ "synopsis" ] ?default:default.p_synopsis
  in
  let p_description =
    EzToml.get_string_option table [ "description" ]
      ?default:default.p_description
  in
  let p_pack_modules =
    EzToml.get_bool_option table [ "pack-modules" ]
      ?default:default.p_pack_modules
  in
  let p_optional =
    EzToml.get_bool_option table [ "optional" ] ?default:default.p_optional
  in
  let p_dependencies =
    EzToml.get_encoding_default dependencies_encoding table [ "dependencies" ]
      default.p_dependencies
  in
  let p_tools =
    EzToml.get_encoding_default dependencies_encoding table [ "tools" ]
      default.p_tools
  in
  let p_gen_version =
    EzToml.get_string_option table [ "gen-version" ]
      ?default:default.p_gen_version
  in
  let p_skeleton =
    EzToml.get_string_option table [ "skeleton" ] ?default:default.p_skeleton
  in
  let p_generators =
    EzToml.get_encoding_option stringSet_encoding table [ "generators" ]
      ?default:default.p_generators
  in
  let p_menhir =
    EzToml.get_encoding_option menhir_encoding table [ "menhir" ]
  in
  let p_fields =
    EzToml.get_encoding_default fields_encoding table [ "fields" ]
      StringMap.empty
  in
  let p_fields =
    StringMap.union (fun _k a1 _a2 -> Some a1) p_fields default.p_fields
  in
  if Globals.verbose_subst then
    StringMap.iter
      (fun k _ -> Printf.eprintf "Package defined field %S\n%!" k)
      p_fields;
  let p_skip =
    EzToml.get_encoding_option skip_encoding table [ "skip" ]
      ?default:default.p_skip
  in
  let p_sites =
    match Toml.Lenses.get table Toml.Lenses.(key "sites" |-- table) with
    | None -> Sites.default
    | Some toml -> EzToml.TYPES.TTable toml |> Sites.of_eztoml in
  { name;
    dir;
    project;
    p_pack;
    p_preprocess;
    p_file;
    kind;
    p_version;
    p_authors;
    p_synopsis;
    p_description;
    p_dependencies;
    p_tools;
    p_pack_modules;
    p_gen_version;
    p_fields;
    p_skeleton;
    p_generators;
    p_menhir;
    p_skip;
    p_optional;
    p_sites;
  }

let of_toml ?default table =
  let dir = EzToml.get_string_option table [ "dir" ] in
  let table, p_file =
    match dir with
    | None -> (table, None)
    | Some dir ->
      let filename = dir // "package.toml" in
      if Sys.file_exists filename then
        let package_table =
          match EzToml.from_file filename with
          | `Ok table -> table
          | `Error (s, loc) ->
            Error.raise "Could not parse %S: %s at %s" filename s
              (EzToml.string_of_location loc)
        in
        let table =
          Toml.Types.Table.union
            (fun _key _ v ->
              Some v
              (*
                Error.raise "File %s: key %s already exist in drom.toml"
                  filename (Toml.Types.Table.Key.to_string key)
*)
              )
            package_table table
        in
        (table, Some filename)
      else
        (table, None)
  in
  of_toml ?default ?p_file table

let of_string ~msg ?default content =
  let table =
    match EzToml.from_string content with
    | `Ok table -> table
    | `Error (s, loc) ->
        Error.raise "Could not parse:\n<<<\n%s\n>>>\n at %s" content msg s
          (EzToml.string_of_location loc)
  in
  of_toml ?default table
