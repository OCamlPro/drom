(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open DromTypes

(*
`opam-new create project` will generate the tree:
* project/
    drom.toml
    .git/
    .gitignore
    dune-workspace
    dune-project     [do not edit]
    project.opam     [do not edit]
    src/
       dune          [do not edit]
       main.ml

drom.toml looks like:
```
[package]
authors = ["Fabrice Le Fessant <fabrice.le_fessant@origin-labs.com>"]
edition = "4.10.0"
library = false
name = "project"
version = "0.1.0"

[dependencies]

[tools]
dune = "2.6.0"
```

*)


open EzFile.OP

(* Most used licenses in the opam repository:
    117 license: "GPL-3.0-only"
    122 license: "LGPL-2.1"
    122 license: "LGPL-2.1-only"
    130 license:      "MIT"
    180 license: "BSD-2-Clause"
    199 license: "LGPL-2.1-or-later with OCaml-LGPL-linking-exception"
    241 license: "LGPL-3.0-only with OCaml-LGPL-linking-exception"
    418 license: "LGPL-2.1-only with OCaml-LGPL-linking-exception"
    625 license:      "ISC"
    860 license: "BSD-3-Clause"
   1228 license: "Apache-2.0"
   1555 license: "ISC"
   2785 license: "MIT"
*)

let git_config =
  lazy
    (
      Configparser.parse_string
        ( EzFile.read_file
            ( DromGlobals.home_dir // ".gitconfig" ) )
    )

let user_of_git_config () =
  Configparser.get ( Lazy.force git_config ) "user" "name"

let email_of_git_config () =
  Configparser.get ( Lazy.force git_config ) "user" "email"

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
    |> EzToml.put_string [ "package" ; "name" ] p.name
    |> EzToml.put_string [ "package" ; "version" ] p.version
    |> EzToml.put_string [ "package" ; "edition" ] p.edition
    |> EzToml.put [ "package" ; "library" ]
      ( TomlTypes.TBool p.library )
    |> EzToml.put_string [ "package" ; "synopsis" ] p.synopsis
    |> EzToml.put_string [ "package" ; "description" ] p.description
    |> EzToml.put [ "package"; "authors" ]
      ( TomlTypes.TArray
          ( TomlTypes.NodeString p.authors ) )
  in
  let maybe_package_key key v (table, optionals) =
    match v with
    | None -> ( table, key :: optionals )
    | Some v ->
      ( EzToml.put_string [ "package" ; key ] v table ), optionals
  in
  let package, optionals =
    ( package, [] )
    |> maybe_package_key "github-organization" p.github_organization
    |> maybe_package_key "homepage" p.homepage
    |> maybe_package_key "documentation" p.documentation
    |> maybe_package_key "bug-reports" p.bug_reports
    |> maybe_package_key "dev-repo" p.dev_repo
    |> maybe_package_key "license" p.license
    |> maybe_package_key "copyright" p.copyright
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
      List.fold_left (fun table ( name, version ) ->
          EzToml.put_string [ "dependencies" ; name ] version
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
  Printf.sprintf "%s\n%s\n%s\n%s"
    package optionals dependencies tools

let project_of_toml filename =
  Printf.eprintf "Loading %s\n%!" filename ;
  let table =
    match EzToml.from_file filename with
    | `Ok table -> table
    | `Error _ ->
      Printf.eprintf "Warning: could not parse %S\n%!" filename;
      raise Not_found
  in
  let name = EzToml.get_string table [ "package" ; "name" ] in
  let version = EzToml.get_string_default table [ "package" ; "version" ]
      "0.1.0" in
  let edition = EzToml.get_string_default table [ "package" ; "edition" ]
      DromGlobals.current_ocaml_edition in
  let library = EzToml.get_bool_default table [ "package" ; "library" ] false in
  let authors =
    match EzToml.get table [ "package" ; "authors" ] with
    | TArray ( NodeString authors ) -> authors
    | _ -> error "Cannot parse authors field in drom.toml"
    | exception Not_found ->
      error "No field 'authors' in drom.toml"
  in
  let dependencies = match EzToml.get table [ "dependencies" ] with
    | exception Not_found -> []
    | TTable deps ->
      let dependencies = ref [] in
      TomlTypes.Table.iter (fun name version ->
          let name = TomlTypes.Table.Key.to_string name in
          let version = match version with
            | TomlTypes.TString s -> s
            | _ -> failwith "Bad dependency version"
          in
          dependencies := ( name, version ) :: !dependencies ) deps ;
      !dependencies
    | _ -> failwith "Cannot load dependencies"
  in
  let tools = match EzToml.get table [ "tools" ] with
    | exception Not_found -> [ "dune", DromGlobals.current_dune_version ]
    | TTable deps ->
      let dependencies = ref [] in
      TomlTypes.Table.iter (fun name version ->
          let name = TomlTypes.Table.Key.to_string name in
          let version = match version with
            | TomlTypes.TString s -> s
            | _ -> failwith "Bad tool version"
          in
          dependencies := ( name, version ) :: !dependencies ) deps ;
      !dependencies
    | _ -> failwith "Cannot load tools"
  in
  let synopsis =
    EzToml.get_string_default table [ "package"; "synopsis" ]
      ( DromGlobals.default_synopsis ~name ) in
  let description =
    EzToml.get_string_default table [ "package"; "description" ]
      ( DromGlobals.default_description ~name ) in
  let github_organization =
    EzToml.get_string_option table [ "package" ; "github-organization" ] in
  let documentation =
    EzToml.get_string_option table [ "package" ; "documentation" ] in
  let homepage =
    EzToml.get_string_option table [ "package" ; "homepage" ] in
  let bug_reports =
    EzToml.get_string_option table [ "package" ; "bug-reports" ] in
  let dev_repo =
    EzToml.get_string_option table [ "package" ; "dev-repo" ] in
  let license =
    EzToml.get_string_option table [ "package" ; "license" ] in
  let copyright =
    EzToml.get_string_option table [ "package" ; "copyright" ] in
  {
    name ;
    version ;
    edition ;
    library ;
    authors ;
    synopsis ;
    description ;
    dependencies ;
    tools ;
    github_organization ;
    documentation ;
    homepage ;
    license ;
    bug_reports ;
    dev_repo ;
    copyright ;
  }
