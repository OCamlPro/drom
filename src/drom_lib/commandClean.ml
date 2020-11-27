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

let cmd_name = "clean"

let action ~opam =
  let _p,_ = Project.get () in
  Printf.eprintf "Removing _build...\n%!";
  ignore (Sys.command "rm -rf _build");
  if !opam then (
    ignore (Sys.command "rm -rf _drom");
    ignore (Sys.command "rm -rf _opam")
  )

let cmd =
  let opam = ref false in
  EZCMD.sub
    cmd_name
    (fun () -> action ~opam)
    ~args:
      [ ( [ "opam" ],
          Arg.Set opam,
          EZCMD.info "Also remove the local opam switch (_opam/ and _drom/)" )
      ]
    ~doc: "Clean the project from build files"
