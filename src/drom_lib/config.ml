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
  (* Printf.eprintf "Loading config from %s\n%!" filename ; *)
  match EzToml.from_file filename with
  | `Error _ -> Error.raise "Could not parse config file %S" filename
  | `Ok table ->
    let config_author = EzToml.get_string_option table [ "user"; "author" ] in
    let config_github_organization =
      EzToml.get_string_option table [ "user"; "github-organization" ]
    in
    let config_license = EzToml.get_string_option table [ "user"; "license" ] in
    let config_share_dir =
      EzToml.get_string_option table [ "user"; "share-dir" ]
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
    { config_author;
      config_github_organization;
      config_share_dir;
      config_license;
      config_copyright;
      config_opam_repo;
      config_dev_tools;
      config_auto_upgrade ;
    }

let config_template =
  {|
[user]
# author = "Author Name <email>"
# github-organization = "...organization..."
# license = "...license..."
# copyright = "Company Ltd"
# opam-repo = "/home/user/GIT/opam-repository"
# dev-tools = [ "merlin", "tuareg" ]
# auto-upgrade = false
|}


let update_with oldc newc =
  {
    config_author = ( match newc.config_author, oldc.config_author with
        | None, oldc -> oldc
        | newc, _ -> newc ) ;
    config_github_organization =
      ( match newc.config_github_organization,
              oldc.config_github_organization with
        | None, oldc -> oldc
        | newc, _ -> newc ) ;
    config_share_dir = ( match newc.config_share_dir, oldc.config_share_dir with
        | None, oldc -> oldc
        | newc, _ -> newc ) ;
    config_license = ( match newc.config_license, oldc.config_license with
        | None, oldc -> oldc
        | newc, _ -> newc ) ;
    config_copyright = ( match newc.config_copyright, oldc.config_copyright with
        | None, oldc -> oldc
        | newc, _ -> newc ) ;
    config_opam_repo = ( match newc.config_opam_repo, oldc.config_opam_repo with
        | None, oldc -> oldc
        | newc, _ -> newc ) ;
    config_dev_tools = ( match newc.config_dev_tools, oldc.config_dev_tools with
        | None, oldc -> oldc
        | newc, _ -> newc ) ;
    config_auto_upgrade = ( match newc.config_auto_upgrade, oldc.config_auto_upgrade with
        | None, oldc -> oldc
        | newc, _ -> newc ) ;
  }

let getenv_opt v = match Sys.getenv v with
  | exception Not_found -> None
  | s -> Some s

let load () =
  let config_file = Globals.config_dir // "config" in

  if not @@ Sys.file_exists config_file then begin
    EzFile.make_dir ~p:true Globals.config_dir;
    EzFile.write_file config_file config_template
  end;

  let config_home = config_of_toml config_file in

  let config_env = {
    config_author = getenv_opt "DROM_AUTHOR" ;
    config_github_organization = getenv_opt "DROM_GITHUB_ORGANIZATION" ;
    config_license = getenv_opt "DROM_GITHUB_ORGANIZATION" ;
    config_copyright = getenv_opt "DROM_COPYRIGHT" ;
    config_opam_repo = getenv_opt "DROM_OPAM_REPO" ;
    config_share_dir = getenv_opt "DROM_SHARE_DIR" ;
    config_dev_tools = None ;
    config_auto_upgrade = ( match getenv_opt "DROM_AUTO_UPGRADE" with
        | None -> None
        | Some ( "no" | "0" | "n" | "N" ) -> Some false
        | _ -> Some true ) ;
  }
  in
  let path = Sys.getcwd () in
  let rec iter path =
    let new_path = Filename.dirname path in
    let config =
      if new_path <> path then
        iter new_path
      else
        update_with config_home  config_env
    in
    let file = path // ".drom.config" in
    if Sys.file_exists file then begin
      if !Globals.verbosity > 1 then
        Printf.eprintf "Loading local user config from %s\n%!" file;
      let config_local = config_of_toml file in
      update_with config config_local
    end
    else
      config
  in
  iter path

let config = lazy (load ())

let find_share_dir ?(for_copy=false) () =
  let share_dirs =
    (
      if for_copy then [] else
        match Sys.getenv "DROM_SHARE_DIR" with
        | share_dir -> [ Some "env var DROM_SHARE_DIR", share_dir ]
        | exception Not_found -> []
    )
    @
    (
      match
        Globals.find_ancestor_file "share"
          (fun ~dir ~path:_ -> dir)
      with
      | None -> []
      | Some dir -> [ Some "local ./share/drom", dir // "share" // "drom" ]
    )
    @
    (
      if for_copy then [] else
        [ None, Globals.opam_root () // "plugins" // "opam-drom" ]
    )
    @
    (
      match Globals.opam_switch_prefix with
      | Some opam_switch_prefix ->
          let share_dir = opam_switch_prefix // "share" // Globals.command in
          [ Some "OPAM_SWITCH_PREFIX", share_dir ]
      | None -> []
    )
    @
    (
      if for_copy then [] else
        let config = Lazy.force config in
        match config.config_share_dir with
        | None -> []
        | Some share_dir -> [ Some "user config share_dir", share_dir ]
    )
  in
  let rec iter msgs = function
      [] ->
        if !Globals.verbosity > 0 then begin
          Printf.eprintf
            "Warning: drom is not correctly configured, no share_dir found\n%!";
          List.iter (fun (msg, dir) ->
              Printf.eprintf
                "   * %s points to directory with missing %S\n%!"
                msg dir;
            ) msgs;
        end;
        None

    | (msg, share_dir) :: dirs ->

        let skeletons_dir = share_dir // "skeletons" in
        if not ( Sys.file_exists skeletons_dir ) then begin
          let msgs =
            match msg with
            | None -> msgs
            | Some msg -> (msg, skeletons_dir) :: msgs
          in
          iter msgs dirs
        end else
          Some share_dir
  in
  iter [] share_dirs

let share_dir = lazy ( find_share_dir () )
let share_dir () = Lazy.force share_dir

let config () = Lazy.force config
