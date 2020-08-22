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
  let _p = Build.build () in
  Printf.eprintf "Build OK\n%!"

let cmd =
  {
    cmd_name ;
    cmd_action = (fun () -> action ());
    cmd_args = [
    ];
    cmd_man = [];
    cmd_doc = "Build a project";
  }
