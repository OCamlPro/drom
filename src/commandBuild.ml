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

let action ~args () =
  let ( _p : Types.project ) = Build.build ~args () in
  Printf.eprintf "Build OK\n%!"

let cmd =
  let ( args, specs ) =  Build.build_args () in
  {
    cmd_name ;
    cmd_action = (fun () -> action ~args ());
    cmd_args = [
    ] @ specs ;
    cmd_man = [];
    cmd_doc = "Build a project";
  }
