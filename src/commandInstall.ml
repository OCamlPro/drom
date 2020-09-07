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

let action ~args () =
  let _p = Build.build ~args () in
  let packages = Misc.list_opam_packages "." in
  (* (1) uninstall formerly install packages *)
  List.iter (fun package ->
      match Opam.run [ "uninstall" ] [ "-y" ; package ] with
      | exception Types.Error _ -> ()
      | () -> ()
    ) packages ;
  (* (2) pin packages of this directory as they are *)
  Opam.run [ "pin" ] [ "-y" ; "--no-action"; "-k" ; "path" ; "."  ];
  (* (3) install packages *)
  let exn = match
      Opam.run [ "install" ] ( "-y" :: packages )
    with
    | () -> None
    | exception exn -> Some exn
  in
  (* (4) unpin packages to clean the state *)
  List.iter (fun package ->
      Opam.run ~error:(ref None) [ "unpin" ] [ "-n" ; package ]
    ) packages ;
  match exn with
  | None ->
    Printf.eprintf "\nInstallation OK\n%!"
  | Some exn -> raise exn

let cmd =
  let args, specs = Build.build_args () in
  {
    cmd_name ;
    cmd_action = (fun () -> action ~args ());
    cmd_args = [] @ specs ;
    cmd_man = [];
    cmd_doc = "Build & install the project in the project opam switch";
  }
