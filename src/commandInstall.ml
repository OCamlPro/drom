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
  Misc.opam [ "pin" ] [ "-y" ; "-k" ; "path" ; "."  ];
  let packages =
    let packages = ref [] in
    let files = match Sys.readdir "." with
      | exception _ -> [||]
      | files -> files
    in
    Array.iter (fun file ->
        if Filename.check_suffix file ".opam" then
          let package = Filename.chop_suffix file ".opam" in
          packages := package :: !packages
      ) files ;
    !packages
  in
  Misc.opam [ "unpin" ] ( "-n" :: packages )

let cmd =
  let args, specs = Build.build_args () in
  {
    cmd_name ;
    cmd_action = (fun () -> action ~args ());
    cmd_args = [] @ specs ;
    cmd_man = [];
    cmd_doc = "Build & install the project in the local opam switch _opam";
  }
