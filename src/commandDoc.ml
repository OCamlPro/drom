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

let cmd_name = "doc"

let action ~switch () =
  let ( _p : Types.project ) =
    Build.build ~dev_deps:true  ~switch () in
  Misc.call [| "opam" ; "exec"; "--" ; "dune" ; "build" ; "@doc" |];
  Misc.call [|
    "rsync" ; "-auv" ; "--delete" ;
    "_build/default/_doc/_html/." ;
    "docs/doc"
  |]

let cmd =
  let switch = ref None in
  {
    cmd_name ;
    cmd_action = (fun () -> action ~switch ());
    cmd_args =
      [] @
      Build.switch_args switch;
    cmd_man = [];
    cmd_doc = "Generate API documentation using odoc";
  }
