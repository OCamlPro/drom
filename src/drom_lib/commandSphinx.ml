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
  let args, _ = Build.build_args () in
  let (p : Types.project) =
    Build.build ~setup_opam:false ~build_deps:false ~build:false ~args ()
  in

  let sphinx_target =
    match p.sphinx_target with
    | None -> "docs/sphinx"
    | Some dir -> dir
  in
  Misc.call [| "sphinx-build"; "sphinx"; sphinx_target |];
  if not (List.mem "git-add-sphinx" p.skip) then
    Misc.call [| "git"; "add"; sphinx_target |]

let cmd =
  { cmd_name;
    cmd_action = (fun () -> action ());
    cmd_args = [];
    cmd_man = [];
    cmd_doc = "Generate general documentation using sphinx"
  }
