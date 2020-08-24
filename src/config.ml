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

open EzFile.OP

let config_of_toml filename =
  Printf.eprintf "Loading config from %s\n%!" filename ;
  match EzToml.from_file filename with
  | `Error _ ->
    Error.printf "Could not parse config file %S" filename;
  | `Ok table ->
    let config_author =
      EzToml.get_string_option table [ "user" ; "author" ] in
    let config_github_organization =
      EzToml.get_string_option table [ "user" ; "github-organization" ] in
    let config_license =
      EzToml.get_string_option table [ "user" ; "license" ] in
    let config_copyright =
      EzToml.get_string_option table [ "user" ; "copyright" ] in
    {
      config_author ;
      config_github_organization ;
      config_license ;
      config_copyright ;
    }

let config_template = {|
[user]
# author = "Author Name <email>"
# github-organization = "...organization..."
# license = "...license..."
# copyright = "Company Ltd"
|}

let load () =
  let filename = Globals.config_dir // "config" in

  if not ( Sys.file_exists filename ) then begin
    EzFile.make_dir ~p:true Globals.config_dir ;
    EzFile.write_file filename config_template;
  end ;

  let config = config_of_toml filename in

  let config = match Sys.getenv "DROM_AUTHOR" with
    | s -> { config with config_author = Some s }
    | exception Not_found -> config
  in

  let config = match Sys.getenv "DROM_GITHUB_ORGANIZATION" with
    | s -> { config with config_github_organization = Some s }
    | exception Not_found -> config
  in

  let config = match Sys.getenv "DROM_LICENSE" with
    | s -> { config with config_license = Some s }
    | exception Not_found -> config
  in

  let config = match Sys.getenv "DROM_COPYRIGHT" with
    | s -> { config with config_copyright = Some s }
    | exception Not_found -> config
  in

  config

let config = lazy ( load () )
