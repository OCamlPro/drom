(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open EzFile.OP

let command = "drom"

let about =
  Printf.sprintf "%s %s by OCamlPro SAS <contact@ocamlpro.com>" command
    Version.version

let current_ocaml_edition = "4.10.0"

let current_dune_version = "2.6.0"

let default_synopsis ~name = Printf.sprintf "The %s project" name

let default_description ~name =
  Printf.sprintf "This is the description\nof the %s OCaml project\n" name

let drom_dir = "_drom"

let drom_file = "drom.toml"

module App_id = struct
  let qualifier = "com"
  let organization = "OCamlPro"
  let application = "drom"
end
module Base_dirs = Directories.Base_dirs ()
module Project_dirs = Directories.Project_dirs (App_id)

let home_dir =
  match Base_dirs.home_dir with
  | None ->
      Format.eprintf "Error: can't compute HOME path, make sure it is well defined !@.";
      exit 2
  | Some home_dir -> home_dir

let config_dir =
  match Project_dirs.config_dir with
  | None ->
      Format.eprintf "Error: can't compute configuration path, make sure your HOME and other environment variables are well defined !@.";
      exit 2
  | Some config_dir -> config_dir

let min_drom_version = "0.1"

let verbosity = ref 1

let opam_switch_prefix =
  match Sys.getenv "OPAM_SWITCH_PREFIX" with
  | exception Not_found -> None
  | switch_dir -> Some switch_dir

let find_ancestor_file file f =
  let dir = Sys.getcwd () in
  let rec iter dir path =
    let drom_file = dir // file in
    if Sys.file_exists drom_file then
      Some ( f ~dir ~path )
    else
      let updir = Filename.dirname dir in
      if updir <> dir then
        iter updir (Filename.basename dir // path)
      else
        None
  in
  iter dir ""

let share_dir =
  lazy (
    match
      match
        find_ancestor_file "share"
          (fun ~dir ~path:_ -> dir)
      with
      | None -> None
      | Some dir ->
          let local_dir = dir // "share" // command in
          if Sys.file_exists ( local_dir // "skeletons" ) then begin
            Printf.eprintf "Warning: using local share dir: %s\n%!" local_dir;
            Some local_dir
          end else
            None
    with
      Some share_dir -> Some share_dir
    | None ->
        match opam_switch_prefix with
        | Some opam_switch_prefix ->
            let share_dir = opam_switch_prefix // "share" // command in
            let skeletons_dir = share_dir // "skeletons" in
            if Sys.file_exists share_dir then
              Some share_dir
            else begin
              Printf.eprintf
                "Warning: drom is not correctly installed in this switch:\n";
              Printf.eprintf "%s is missing\n%!" skeletons_dir;
              None
            end
        | None ->
            Printf.eprintf "Warning: drom is not correctly configured, missing opam switch\n%!";
            None
  )

let share_dir () = Lazy.force share_dir
