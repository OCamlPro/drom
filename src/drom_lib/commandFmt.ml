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

let cmd_name = "fmt"

let action ~args ~auto_promote () =
  let (_p : Types.project) = Build.build ~dev_deps:true ~build:false ~args () in
  Misc.call
    (Array.of_list
       ( [ "opam"; "exec"; "--"; "dune"; "build"; "@fmt" ]
       @
       if auto_promote then
         [ "--auto-promote" ]
       else
         [] ))

let cmd =
  let auto_promote = ref false in
  let args, specs = Build.build_args () in
  { cmd_name;
    cmd_action = (fun () -> action ~args ~auto_promote:!auto_promote ());
    cmd_args =
      [ ( [ "auto-promote" ],
          Arg.Set auto_promote,
          Ezcmd.info "Promote detected changes immediately" )
      ]
      @ specs;
    cmd_man = [];
    cmd_doc = "Format sources with ocamlformat"
  }
