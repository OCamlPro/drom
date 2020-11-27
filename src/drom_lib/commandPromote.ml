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

let cmd_name = "promote"

let action ~args () =
  let (_p : Types.project) = Build.build ~dev_deps:true ~build:false ~args () in
  Misc.call (Array.of_list [ "opam"; "exec"; "--"; "dune"; "promote" ])

let cmd =
  let args, specs = Build.build_args () in
  EZCMD.sub cmd_name
    (fun () -> action ~args ())
    ~args: specs
    ~doc: "Promote detected changes after running drom test or drom fmt"
