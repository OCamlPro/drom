(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Ezcmd.TYPES

let cmd_name = "build"

let action () =
  let p = DromToml.project_of_toml "drom.toml" in
  let build = true in
  let create = false in
  DromUpdate.update_files ~create ~build p ;
  DromMisc.call [| "opam" ; "exec"; "--" ; "dune" ; "build" |]

let cmd =
  {
    cmd_name ;
    cmd_action = (fun () -> action ());
    cmd_args = [
    ];
    cmd_man = [];
    cmd_doc = "Build a project";
  }
