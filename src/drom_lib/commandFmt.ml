(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Ezcmd.V2
open EZCMD.TYPES

let cmd_name = "fmt"

let action ~args ~auto_promote () =
  let (_p : Types.project) = Build.build ~dev_deps:true ~build:false ~args () in
  Misc.before_hook "fmt";
  Misc.call
    (Array.of_list
       ( [ "opam"; "exec"; "--"; "dune"; "build"; "@fmt" ]
       @
       if auto_promote then
         [ "--auto-promote" ]
       else
         [] ));
  Misc.after_hook "fmt";
  ()

let cmd =
  let auto_promote = ref false in
  let args, specs = Build.build_args () in
  EZCMD.sub cmd_name
    (fun () -> action ~args ~auto_promote:!auto_promote ())
    ~args: (
      [ ( [ "auto-promote" ],
          Arg.Set auto_promote,
          EZCMD.info "Promote detected changes immediately" )
      ]
      @ specs )
    ~doc: "Format sources with ocamlformat"
