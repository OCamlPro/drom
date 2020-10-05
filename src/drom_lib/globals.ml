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

let home_dir =
  try Sys.getenv "HOME"
  with Not_found ->
    Printf.eprintf "Error: HOME variable not defined\n%!";
    exit 2

let default_synopsis ~name = Printf.sprintf "The %s project" name

let default_description ~name =
  Printf.sprintf "This is the description\nof the %s OCaml project\n" name

let drom_dir = "_drom"

let xdg_config_dir =
  match Sys.getenv "XDG_CONFIG_HOME" with
  | "" -> home_dir // ".config"
  | exception Not_found -> home_dir // ".config"
  | x -> x

let config_dir = xdg_config_dir // "drom"

let min_drom_version = "0.1.0"

let verbosity = ref 1
