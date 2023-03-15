(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Ez_file.V1
open Types
open EzFile.OP

let config_of_toml filename =
  (* Printf.eprintf "Loading config from %s\n%!" filename ; *)
  match EzToml.from_file filename with
  | `Error _ -> Error.raise "Could not parse config file %S" filename
  | `Ok table ->
    let config_author = EzToml.get_string_option table [ "user"; "author" ] in
    let config_github_organization =
      EzToml.get_string_option table [ "user"; "github-organization" ]
    in
    let config_license = EzToml.get_string_option table [ "user"; "license" ] in
    let config_share_repo =
      EzToml.get_string_option table [ "user"; "share-repo" ]
    in
    let config_copyright =
      EzToml.get_string_option table [ "user"; "copyright" ]
    in
    let config_opam_repo =
      EzToml.get_string_option table [ "user"; "opam-repo" ]
    in
    let config_dev_tools =
      EzToml.get_string_list_option table [ "user"; "dev-tools" ]
      (* [ "merlin" ; "ocp-indent" ] *)
    in
    let config_auto_upgrade =
      EzToml.get_bool_option table [ "user"; "auto-upgrade" ]
    in
    let config_auto_opam_yes =
      EzToml.get_bool_option table [ "user"; "auto-opam-yes" ]
    in
    let config_git_stage =
      EzToml.get_bool_option table [ "user"; "git-stage" ]
    in
    { config_author;
      config_github_organization;
      config_share_repo;
      config_license;
      config_copyright;
      config_opam_repo;
      config_dev_tools;
      config_auto_upgrade;
      config_auto_opam_yes;
      config_git_stage;
    }

let config_template =
  {|
[user]
# author = "Author Name <email>"
# github-organization = "...organization..."
# license = "...license..."
# copyright = "Company Ltd"
## Location of your local project opam-repo:
# opam-repo = "/home/user/GIT/opam-repository"
# dev-tools = [ "merlin", "tuareg" ]
## Do not upgrade project at 'drom build'
# auto-upgrade = false
## Do not call opam with -y for local opam switches:
# auto-opam-yes = false
## Do not automatically stage files with git
# git-stage = false
|}

let update_with oldc newc =
  { config_author =
      ( match (newc.config_author, oldc.config_author) with
      | None, oldc -> oldc
      | newc, _ -> newc );
    config_github_organization =
      ( match
          (newc.config_github_organization, oldc.config_github_organization)
        with
      | None, oldc -> oldc
      | newc, _ -> newc );
    config_share_repo =
      ( match (newc.config_share_repo, oldc.config_share_repo) with
      | None, oldc -> oldc
      | newc, _ -> newc );
    config_license =
      ( match (newc.config_license, oldc.config_license) with
      | None, oldc -> oldc
      | newc, _ -> newc );
    config_copyright =
      ( match (newc.config_copyright, oldc.config_copyright) with
      | None, oldc -> oldc
      | newc, _ -> newc );
    config_opam_repo =
      ( match (newc.config_opam_repo, oldc.config_opam_repo) with
      | None, oldc -> oldc
      | newc, _ -> newc );
    config_dev_tools =
      ( match (newc.config_dev_tools, oldc.config_dev_tools) with
      | None, oldc -> oldc
      | newc, _ -> newc );
    config_auto_upgrade =
      ( match (newc.config_auto_upgrade, oldc.config_auto_upgrade) with
      | None, oldc -> oldc
      | newc, _ -> newc );
    config_auto_opam_yes =
      ( match (newc.config_auto_opam_yes, oldc.config_auto_opam_yes) with
      | None, oldc -> oldc
      | newc, _ -> newc );
    config_git_stage =
      ( match (newc.config_git_stage, oldc.config_git_stage) with
      | None, oldc -> oldc
      | newc, _ -> newc );
  }

let getenv_opt v =
  match Sys.getenv v with
  | exception Not_found -> None
  | s -> Some s

let getenv_bool_opt v =
  match getenv_opt v with
  | None -> None
  | Some ("no" | "0" | "n" | "N") -> Some false
  | _ -> Some true

let load () =
  let config_file = Globals.config_dir // "config" in

  if not @@ Sys.file_exists config_file then begin
    EzFile.make_dir ~p:true Globals.config_dir;
    EzFile.write_file config_file config_template
  end;

  let config_home = config_of_toml config_file in

  let config_env =
    { config_author = getenv_opt "DROM_AUTHOR";
      config_github_organization = getenv_opt "DROM_GITHUB_ORGANIZATION";
      config_license = getenv_opt "DROM_GITHUB_ORGANIZATION";
      config_copyright = getenv_opt "DROM_COPYRIGHT";
      config_opam_repo = getenv_opt "DROM_OPAM_REPO";
      config_share_repo = getenv_opt "DROM_SHARE_REPO";
      config_dev_tools = None;
      config_auto_upgrade = getenv_bool_opt "DROM_AUTO_UPGRADE";
      config_auto_opam_yes = getenv_bool_opt "DROM_AUTO_OPAM_YES";
      config_git_stage = getenv_bool_opt "DROM_GIT_STAGE";
    }
  in
  let path = Sys.getcwd () in
  let rec iter path =
    let new_path = Filename.dirname path in
    let config =
      if new_path <> path then
        iter new_path
      else
        update_with config_home config_env
    in
    let file = path // ".drom.config" in
    if Sys.file_exists file then begin
      if !Globals.verbosity > 1 then
        Printf.eprintf "Loading local user config from %s\n%!" file;
      let config_local = config_of_toml file in
      update_with config config_local
    end else
      config
  in
  iter path

let config = lazy (load ())
let get () = Lazy.force config
