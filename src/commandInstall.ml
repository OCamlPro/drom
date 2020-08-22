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

let cmd_name = "install"

let action () =
  let p = Build.build () in
  Misc.call [| "opam" ; "exec"; "--" ; "dune" ; "install" ; "-p" ; p.name |]

let cmd =
  {
    cmd_name ;
    cmd_action = (fun () -> action ());
    cmd_args = [
    ];
    cmd_man = [];
    cmd_doc = "Build & install the project in the local opam switch _opam";
  }
