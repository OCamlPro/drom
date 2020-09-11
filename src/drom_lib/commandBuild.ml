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
open EzFile.OP
open Types

let cmd_name = "build"

let action ~args () =
  let (p : Types.project) = Build.build ~args () in
  let n = ref 0 in
  List.iter (fun package ->
      match package.kind with
      | Library -> ()
      | Virtual -> ()
      | Program ->
          if Sys.file_exists package.name then
            Sys.remove package.name ;
          let src =
            "_build/default" // package.dir // "main.exe" in
          if Sys.file_exists src then begin
            let s = EzFile.read_file src in
            EzFile.write_file package.name s;
            incr n;
            Unix.chmod  package.name 0o755
          end else
            Printf.eprintf "Warning: target %s not found.\n%!" src
    ) p.packages;
  Printf.eprintf "\nBuild OK%s\n%!"
    (if !n>0 then
       Printf.sprintf " ( %d command%s generated )" !n
         (if !n>1 then "s" else "")
     else
       "")

let cmd =
  let args, specs = Build.build_args () in
  {
    cmd_name;
    cmd_action = (fun () -> action ~args ());
    cmd_args = [] @ specs;
    cmd_man = [];
    cmd_doc = "Build a project";
  }
