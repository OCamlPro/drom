(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Ezcmd.V2
open EZCMD.TYPES

let cmd_name = "clean"

let action ~distclean =
  let _p, _ = Project.get () in
  Printf.eprintf "Removing _build...\n%!";
  Call.before_hook ~command:"clean" ();
  ignore (Sys.command "rm -rf _build");
  Call.after_hook ~command:"clean" ();
  if !distclean then begin
    Call.before_hook ~command:"distclean" ();
    ignore (Sys.command "rm -rf _drom");
    ignore (Sys.command "rm -rf _opam");
    Call.after_hook ~command:"distclean" ()
  end

let cmd =
  let distclean = ref false in
  EZCMD.sub cmd_name
    (fun () -> action ~distclean)
    ~args:
      [ ( [ "distclean" ],
          Arg.Set distclean,
          EZCMD.info "Also remove _opam/ (local switch) and _drom/" )
      ]
    ~doc:"Clean the project from build files"
