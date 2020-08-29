(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Types

let rec dummy_project = {
  package = dummy_package ;
  edition = "dummy_project.edition" ;
  min_edition = "dummy_project.min_edition" ;
  kind = Program ;
  github_organization = None ;
  homepage = None ;
  license = "dummy_project.license" ;
  copyright = None ;
  bug_reports = None ;
  dev_repo = None ;
  doc_gen = None ;
  doc_api = None ;
  skip = [] ;
  version = "dummy_project.version" ;
  authors = [ "dummy_project.authors" ] ;
  synopsis = "dummy_project.synopsis " ;
  description = "dummy_project.description" ;
  dependencies = [];
  tools = [] ;
  mode = Binary ;
  pack_modules = true ;
  archive = None ;
  sphinx_target = None ;
}

and dummy_package = {
  name = "dummy_package" ;
  dir = "dummy_package.dir" ;
  project = dummy_project ;
  p_pack = None ;
  p_kind = None ;
  p_version = None ;
  p_authors = None ;
  p_synopsis = None ;
  p_description = None ;
  p_dependencies = None ;
  p_tools = None ;
  p_mode = None ;
  p_pack_modules = None ;
}

let create_package ~name ~dir = {
  dummy_package with
  name ;
  dir ;
}

open EzFile.OP

let git_config =
  lazy
    (
      Configparser.parse_string
        ( EzFile.read_file
            ( Globals.home_dir // ".gitconfig" ) )
    )

let user_of_git_config () =
  Configparser.get ( Lazy.force git_config ) "user" "name"

let email_of_git_config () =
  Configparser.get ( Lazy.force git_config ) "user" "email"

let kind_encoding =
  EzToml.encoding
    ~to_toml:(function
        | Library -> "library"
        | Program -> "program"
        | Both -> "both"
      )
    ~of_toml:(function
        | "lib" | "library" -> Library
        | "both" -> Both
        | "program" | "executable" | "exe" -> Program
        | kind ->
          Error.raise
            {|unknown kind %S (should be "library", "program" or "both")|}
            kind
      )

let mode_encoding =
  EzToml.encoding
    ~to_toml:(function
        | Binary -> "binary"
        | Javascript -> "javascript"
      )
    ~of_toml:(function
        | "bin" | "binary" -> Binary
        | "js" | "javascript" | "jsoo" -> Javascript
        | mode -> Error.raise
                    {|unknown mode %S (should be "binary" or "javascript")|}
                    mode
      )


let find_author config =
  match config.config_author with
  | Some author -> author
  | None ->
    let user =
      try
        Sys.getenv "DROM_USER"
      with Not_found ->
      try
        Sys.getenv "GIT_AUTHOR_NAME"
      with Not_found ->
      try
        Sys.getenv "GIT_COMMITTER_NAME"
      with Not_found ->
      try
        user_of_git_config ()
      with Not_found ->
      try
        Sys.getenv "USER"
      with Not_found ->
      try
        Sys.getenv "USERNAME"
      with Not_found ->
      try
        Sys.getenv "NAME"
      with Not_found ->
        failwith "Cannot determine user name"
    in
    let email =
      try
        Sys.getenv "DROM_EMAIL"
      with Not_found ->
      try
        Sys.getenv "GIT_AUTHOR_EMAIL"
      with Not_found ->
      try
        Sys.getenv "GIT_COMMITTER_EMAIL"
      with Not_found ->
      try
        email_of_git_config ()
      with Not_found ->
        failwith "Cannot determine user email"
    in
    Printf.sprintf "%s <%s>" user email

let toml_of_project p =
  let package =
    EzToml.empty
    |> EzToml.put_string [ "project" ; "name" ] p.package.name
    |> EzToml.put_string [ "project" ; "version" ] p.version
    |> EzToml.put_string [ "project" ; "edition" ] p.edition
    |> EzToml.put_string [ "project" ; "min-edition" ] p.min_edition
    |> EzToml.put_encoding kind_encoding [ "project" ; "kind" ] p.kind
    |> EzToml.put_encoding mode_encoding [ "project" ; "mode" ] p.mode
    |> EzToml.put_string [ "project" ; "synopsis" ] p.synopsis
    |> EzToml.put_string [ "project" ; "license" ] p.license
    |> EzToml.put_string [ "project" ; "dir" ] p.package.dir
    |> EzToml.put [ "project"; "authors" ]
      ( TArray
          ( TomlTypes.NodeString p.authors ) )
  in
  let maybe_package_key key v (table, optionals) =
    match v with
    | None -> ( table, key :: optionals )
    | Some v ->
      ( EzToml.put_string [ "project" ; key ] v table ), optionals
  in
  let package, optionals =
    ( package, [] )
    |> maybe_package_key "github-organization" p.github_organization
    |> maybe_package_key "homepage" p.homepage
    |> maybe_package_key "doc-gen" p.doc_gen
    |> maybe_package_key "doc-api" p.doc_api
    |> maybe_package_key "bug-reports" p.bug_reports
    |> maybe_package_key "dev-repo" p.dev_repo
    |> maybe_package_key "copyright" p.copyright
    |> maybe_package_key "archive" p.archive
    |> maybe_package_key "sphinx-target" p.sphinx_target
  in
  let package2 =
    EzToml.empty
    |> EzToml.put_string [ "project" ; "description" ] p.description
    |> EzToml.to_string
  in
  let drom =
    EzToml.empty
    |> EzToml.put_string [ "drom" ; "skip" ] ( String.concat " " p.skip )
    |> EzToml.to_string
  in
  let package = EzToml.to_string package in
  let optionals =
    match optionals with
    | [] -> ""
    | optionals ->
      Printf.sprintf "# keys that you could also define:\n# %s\n"
        ( String.concat "\n# "
            ( List.map (fun s -> Printf.sprintf {|%s = "...%s..."|}
                           s s ) optionals ))
  in
  let dependencies =
    match p.dependencies with
    | [] -> "[dependencies]\n"
    | _ ->
      List.fold_left (fun table ( name, d ) ->
          EzToml.put_string [ "dependencies" ; name ]
            (Misc.string_of_dependency d)
            table )
        EzToml.empty p.dependencies
      |> EzToml.to_string
  in
  let tools =
    match p.tools with
    | [] -> "[tools]\n"
    | _ ->
      List.fold_left (fun table ( name, version ) ->
          EzToml.put_string [ "tools" ; name ] version
            table )
        EzToml.empty p.tools
      |> EzToml.to_string
  in
  let package3 =
    EzToml.empty
    |> EzToml.put_bool [ "project" ; "pack-modules" ] p.pack_modules
    |> EzToml.put_string_option [ "project" ; "pack" ] p.package.p_pack
    |> EzToml.to_string
  in
  Printf.sprintf "%s\n%s\n%s\n%s\n%s\n%s%s\n"
    package optionals package2 drom dependencies tools package3

let project_of_toml filename =
  Printf.eprintf "Loading %s\n%!" filename ;
  let table =
    match EzToml.from_file filename with
    | `Ok table -> table
    | `Error _ ->
      Error.raise "Could not parse %S" filename
  in
  let project_key =
    match EzToml.get table [ "package" ] with
    | exception _ -> "project"
    | TTable _ -> "package"
    | TArray _ -> "project"
    | _ -> Error.raise "Unparsable field 'package'"
  in

  let name = EzToml.get_string table [ project_key ; "name" ] in
  let version = EzToml.get_string_default table [ project_key ; "version" ]
      "0.1.0" in
  let edition = EzToml.get_string_option table [ project_key ; "edition" ] in
  let min_edition = EzToml.get_string_option table
      [ project_key ; "min-edition" ] in
  let ( edition, min_edition ) =
    let default_version = Globals.current_ocaml_edition in
    match edition, min_edition with
    | None, None -> default_version, default_version
    | None, Some edition
    | Some edition, None -> edition, edition
    | Some edition, Some min_edition ->
      match VersionCompare.compare min_edition edition with
      | 1 ->
        Error.raise "min-edition is greater than edition in drom.toml"
      | _ -> edition, min_edition
  in
  let mode = EzToml.get_encoding_default mode_encoding table
      [ project_key ; "mode" ] Binary in
  let kind = EzToml.get_encoding_default kind_encoding table
      [ project_key ; "kind" ] Program in
  let authors =
    match EzToml.get table [ project_key ; "authors" ] with
    | TArray ( NodeString authors ) -> authors
    | _ -> Error.raise "Cannot parse authors field in drom.toml"
    | exception Not_found ->
      Error.raise "No field 'authors' in drom.toml"
  in
  let dependencies = match EzToml.get table [ "dependencies" ] with
    | exception Not_found -> []
    | TTable deps ->
      let dependencies = ref [] in
      TomlTypes.Table.iter (fun name version ->
          let name = TomlTypes.Table.Key.to_string name in
          let version = match version with
            | TomlTypes.TString s ->
              Misc.dependency_of_string ~name s
            | _ -> failwith "Bad dependency version"
          in
          dependencies := ( name, version ) :: !dependencies ) deps ;
      !dependencies
    | _ -> failwith "Cannot load dependencies"
  in
  let tools = match EzToml.get table [ "tools" ] with
    | exception Not_found -> [ "dune", Globals.current_dune_version ]
    | TTable deps ->
      let tools = ref [] in
      TomlTypes.Table.iter (fun name version ->
          let name = TomlTypes.Table.Key.to_string name in
          let version = match version with
            | TomlTypes.TString s -> s
            | _ -> failwith "Bad tool version"
          in
          tools := ( name, version ) :: !tools ) deps ;
      !tools
    | _ -> failwith "Cannot load tools"
  in
  let synopsis =
    EzToml.get_string_default table [ project_key; "synopsis" ]
      ( Globals.default_synopsis ~name ) in
  let description =
    EzToml.get_string_default table [ project_key; "description" ]
      ( Globals.default_description ~name ) in
  let github_organization =
    EzToml.get_string_option table [ project_key ; "github-organization" ] in
  let doc_api =
    EzToml.get_string_option table [ project_key ; "doc-api" ] in
  let doc_gen =
    EzToml.get_string_option table [ project_key ; "doc-gen" ] in
  let homepage =
    EzToml.get_string_option table [ project_key ; "homepage" ] in
  let bug_reports =
    EzToml.get_string_option table [ project_key ; "bug-reports" ] in
  let dev_repo =
    EzToml.get_string_option table [ project_key ; "dev-repo" ] in
  let license =
    EzToml.get_string_default table [ project_key ; "license" ]
      License.LGPL2.key in
  let p_pack = EzToml.get_string_option table [ project_key ; "pack" ] in
  let copyright =
    EzToml.get_string_option table [ project_key ; "copyright" ] in
  let archive =
    EzToml.get_string_option table [ project_key ; "archive" ] in
  let skip =
    match EzToml.get_string_option table [ "drom" ; "skip" ] with
    | None -> []
    | Some s -> EzString.split s ' ' in
  let pack_modules =
    match EzToml.get_bool_option table [ project_key ; "pack-modules" ] with
    | Some v -> v
    | None ->
      match EzToml.get_bool_option table [ project_key ; "wrapped" ] with
      | Some v -> v
      | None -> true in
  let dir =
    EzToml.get_string_default table [ project_key ; "dir" ] "src" in
  let sphinx_target =
    EzToml.get_string_option table [ project_key ; "sphinx-target" ] in

  let package = { dummy_package with
                  name ; dir ; p_pack
                }
  in
  let project =
    {
      package ;
      version ;
      edition ;
      kind ;
      min_edition ;
      authors ;
      synopsis ;
      description ;
      dependencies ;
      tools ;
      github_organization ;
      doc_gen ;
      doc_api ;
      homepage ;
      license ;
      bug_reports ;
      dev_repo ;
      copyright ;
      skip ;
      mode ;
      pack_modules ;
      archive ;
      sphinx_target ;
    }
  in
  package.project <- project ;
  project
