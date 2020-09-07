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

let cmd_name = "run"

let action ~args ~cmd =
  let p = Build.build ~args () in
  let cmd = !cmd in
  let cmd =
    match p.package.kind with
    | Library -> cmd
    | Program -> p.package.name :: cmd
    | Virtual -> cmd
  in
  Misc.call
    (Array.of_list
       ( "opam" :: "exec" :: "--" :: "dune" :: "exec" :: "-p" :: p.package.name
       :: "--" :: cmd ))

let cmd =
  let cmd = ref [] in
  let args, specs = Build.build_args () in
  {
    cmd_name;
    cmd_action = (fun () -> action ~args ~cmd);
    cmd_args =
      [
        ( [],
          Arg.Anons (fun list -> cmd := list),
          Ezcmd.info "Arguments to the command" );
      ]
      @ specs;
    cmd_man = [];
    cmd_doc = "Execute the project";
  }
