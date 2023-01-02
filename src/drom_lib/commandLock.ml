(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Ez_file.V1
open Ezcmd.V2
open EzFile.OP
open Types

let cmd_name = "lock"

let action ~args () =
  let (p : Types.project) = Build.build ~args () in

  let opam_basename = p.package.name ^ "-deps.opam" in
  let opam_filename = Globals.drom_dir // opam_basename in
  Misc.call [| "opam"; "lock"; opam_filename |];
  Misc.call [| "git"; "add"; opam_basename ^ ".locked" |];
  ()

let cmd =
  let args, specs = Build.build_args () in
  EZCMD.sub cmd_name
    (fun () -> action ~args ())
    ~args:specs ~doc:"Generate a .locked file for the project" ~version:"0.2.1"
    ~man:
      [ `S "DESCRIPTION";
        `Blocks
          [ `P
              "This command will build the project and call $(b,opam lock) to \
               generate a file $(i,\\${project}-deps.opam.locked) with the \
               exact dependencies used during the build, and that file will be \
               added to the git-managed files of the project to be committed.";
            `P
              "The generated .locked file can be used by other developers to \
               build in the exact same environment by calling $(b,drom build \
               --locked) to build the current project."
          ]
      ]
