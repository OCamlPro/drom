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
      match Misc.opam [ "uninstall" ] [ "-y" ; package ] with
      | exception Types.Error _ -> ()
      | () -> ()
    ) packages ;
  (* (2) pin packages of this directory as they are *)
  Misc.opam [ "pin" ] [ "-y" ; "--no-action"; "-k" ; "path" ; "."  ];
  (* (3) install packages *)
  Misc.opam [ "install" ] ( "-y" :: packages ) ;
  (* (4) unpin packages to clean the state *)
  Misc.opam [ "unpin" ] ( "-n" :: packages ) ;
  ()

let cmd =
  let args, specs = Build.build_args () in
  {
    cmd_name ;
    cmd_action = (fun () -> action ~args ());
    cmd_args = [] @ specs ;
    cmd_man = [];
    cmd_doc = "Build & install the project in the local opam switch _opam";
  }
