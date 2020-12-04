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
      EzToml.get_string_list_default table [ "user"; "dev-tools" ]
        [ "merlin" ; "ocp-indent" ]
    in
    { config_author;
      config_github_organization;
      config_share_dir;
      config_license;
      config_copyright;
      config_opam_repo;
      config_dev_tools;
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
|}



let load () =

  let config_file = Globals.config_dir // "config" in

  if not @@ Sys.file_exists config_file then begin
    EzFile.make_dir ~p:true Globals.config_dir;
    EzFile.write_file config_file config_template
  end;

  let config = config_of_toml config_file in

  let config =
    match Sys.getenv "DROM_AUTHOR" with
    | s -> { config with config_author = Some s }
    | exception Not_found -> config
  in

  let config =
    match Sys.getenv "DROM_GITHUB_ORGANIZATION" with
    | s -> { config with config_github_organization = Some s }
    | exception Not_found -> config
  in

  let config =
    match Sys.getenv "DROM_LICENSE" with
    | s -> { config with config_license = Some s }
    | exception Not_found -> config
  in

  let config =
    match Sys.getenv "DROM_COPYRIGHT" with
    | s -> { config with config_copyright = Some s }
    | exception Not_found -> config
  in

  let config =
    match Sys.getenv "DROM_OPAM_REPO" with
    | s -> { config with config_opam_repo = Some s }
    | exception Not_found -> config
  in

  config

let config = lazy (load ())

let share_dir =
  lazy (
    let share_dirs =
      (
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
      ( let config = Lazy.force config in
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
  )

let share_dir () = Lazy.force share_dir
