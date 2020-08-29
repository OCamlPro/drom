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

let action ~args () =
  let ( p : Types.project ) =
    Build.build ~dev_deps:true  ~args () in
  Misc.call [| "opam" ; "exec"; "--" ; "dune" ; "build" ; "@doc" |];
  Misc.call [|
    "rsync" ; "-auv" ; "--delete" ;
    "_build/default/_doc/_html/." ;
    "docs/doc"
  |];
  if not ( List.mem "git-add-doc" p.skip ) then
    Misc.call [| "git" ; "add" ; "docs/doc" |]

let cmd =
  let ( args, specs ) =  Build.build_args () in
  {
    cmd_name ;
    cmd_action = (fun () -> action ~args ());
    cmd_args =  [] @ specs ;
    cmd_man = [];
    cmd_doc = "Generate API documentation using odoc in the docs/doc directory";
  }
