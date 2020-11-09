(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

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

let min_drom_version = "0.1.0"

let verbosity = ref 1
