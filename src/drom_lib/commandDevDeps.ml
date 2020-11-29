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

let cmd_name = "dev-deps"

let action ~args () =
  let (_p : Types.project) =
    Build.build ~force_dev_deps:true ~dev_deps:true ~build:false ~args ()
  in
  let config = Lazy.force Config.config in
  match config.config_dev_deps with
  | Some dev_deps -> Opam.run ~y:(args.arg_yes) [ "install" ] dev_deps
  | None -> ()

let cmd =
  let args, specs = Build.build_args () in
  { cmd_name;
    cmd_action = (fun () -> action ~args ());
    cmd_args = [] @ specs;
    cmd_man = [];
    cmd_doc = "Install dev dependencies (odoc, ocamlformat, merlin, etc.)"
  }
