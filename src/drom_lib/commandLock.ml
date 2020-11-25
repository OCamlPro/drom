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

let cmd_name = "lock"

let action ~args () =
  let (p : Types.project) = Build.build ~args () in

  let opam_basename = p.package.name ^ "-deps.opam" in
  let opam_filename = Globals.drom_dir // opam_basename in
  Misc.call [| "opam" ; "lock" ; opam_filename |];
  Misc.call [| "git" ; "add" ; opam_basename ^ ".locked" |];
  ()



let cmd =
  let args, specs = Build.build_args () in
  { cmd_name;
    cmd_action = (fun () -> action ~args ());
    cmd_args = [] @ specs;
    cmd_man = [];
    cmd_doc = "Generate a .locked file for the project"
  }
