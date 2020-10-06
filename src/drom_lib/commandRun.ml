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

let action ~args ~cmd ~package =
  (* By default, `drom run` should be quiet *)
  Globals.verbose := false;
  let p = Build.build ~args () in
  let cmd = !cmd in
  let cmd =
    match package with
    | Some package -> package :: cmd
    | None ->
        match p.package.kind with
        | Library -> cmd
        | Program -> p.package.name :: cmd
        | Virtual -> cmd
  in
  Misc.call
    (Array.of_list
       ( "opam" :: "exec" :: "--" :: "dune" :: "exec" :: "--" :: cmd ))

let cmd =
  let cmd = ref [] in
  let package = ref None in
  let args, specs = Build.build_args () in
  {
    cmd_name;
    cmd_action = (fun () -> action ~args ~cmd ~package:!package);
    cmd_args =
      [
        ( ["p"], Arg.String (fun s -> package := Some s),
          Ezcmd.info "Package to run" );
        ( [],
          Arg.Anons (fun list -> cmd := list),
          Ezcmd.info "Arguments to the command" );
      ]
      @ specs;
    cmd_man = [];
    cmd_doc = "Execute the project";
  }
