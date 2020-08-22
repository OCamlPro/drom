(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

let build () =
  let p = Project.project_of_toml "drom.toml" in
  let build = true in
  let create = false in
  Update.update_files ~create ~build p ;
  Misc.call [| "opam" ; "exec"; "--" ; "dune" ; "build" |] ;
  p
