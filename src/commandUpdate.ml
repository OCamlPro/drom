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

let cmd_name = "update"

let action ~args () =

  let ( p : Types.project ) =
    Build.build
      ~force_build_deps:false
      ~build_deps:true
      ~build:false
      ~args () in
  let ( _switch, y, _edition ) = args in
  let y = ! y in

  Opam.run ~y [ "update" ] [] ;
  Opam.run ~y:true [ "pin" ] [
    "-k" ; "path" ; "--no-action" ;
    "./_drom" ] ;
  let deps_package = p.package.name ^ "-deps" in
  Opam.run ~y [ "install" ] [ deps_package ];
  let error = ref None in
  Opam.run ~y ~error [ "upgrade" ] [] ;
  Opam.run ~error [ "unpin" ] [ "-y" ; deps_package ] ;
  match !error with
  | None ->
      Printf.eprintf "Switch Update OK\n%!"
  | Some exn ->
      raise exn



let cmd =
  let ( args, specs ) = Build.build_args () in
  {
    cmd_name ;
    cmd_action = (fun () -> action ~args ());
    cmd_args = [] @ specs ;
    cmd_man = [];
    cmd_doc = "Update packages in switch";
  }
