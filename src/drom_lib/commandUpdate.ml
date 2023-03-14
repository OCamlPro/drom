(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Ezcmd.V2
open Ez_file.V1
open EzFile.OP

let cmd_name = "update"

let action ~args () =
  let (p : Types.project) =
    Build.build ~force_build_deps:false ~build_deps:true ~build:false ~args ()
  in
  let y = args.arg_yes in

  Opam.run ~y [ "update" ] [];
  Opam.run ~y:true [ "pin" ] [ "-k"; "path"; "--no-action"; "./_drom" ];
  let deps_package = p.package.name ^ "-deps" in
  Opam.run ~y [ "install" ] [ deps_package ];
  let error = ref None in
  Opam.run ~y ~error [ "upgrade" ] [];

  (* Generate lock file *)
  let drom_project_deps_opam =
    (Globals.drom_dir // p.package.name) ^ "-deps.opam" in
  Opam.run ~y [ "lock" ] [ "." // drom_project_deps_opam ];
  Opam.run ~error [ "unpin" ] [ "-y"; deps_package ];
  match !error with
  | None -> Printf.eprintf "Switch Update OK\n%!"
  | Some exn -> raise exn

let cmd =
  let args, specs = Build.build_args () in
  EZCMD.sub cmd_name
    (fun () -> action ~args ())
    ~args:specs ~doc:"Update packages in switch"
    ~man:
      [ `S "DESCRIPTION";
        `Blocks
          [ `P "This command performs the following actions:";
            `I
              ( "1.",
                "Call $(b,opam update) to get information on newly available \
                 packages" );
            `I ("2.", "Pin the package dependencies in the local opam switch");
            `I
              ( "3.",
                "Call $(b,opam upgrade) to upgrade packages in the local opam \
                 switch" );
            `I ("4.", "Unpin package dependencies")
          ]
      ]
