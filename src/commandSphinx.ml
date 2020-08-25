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

let cmd_name = "sphinx"

let action () =
  let ( args, _ ) = Build.build_args () in
  let ( _p : Types.project ) =
    Build.build
      ~setup_opam:false
      ~build_deps:false
      ~build:false
      ~args () in
  Misc.call [| "sphinx-build" ; "sphinx" ; "docs/sphinx" |]

let cmd =
  {
    cmd_name ;
    cmd_action = (fun () -> action ());
    cmd_args = [];
    cmd_man = [];
    cmd_doc = "Generate general documentation using sphinx";
  }
