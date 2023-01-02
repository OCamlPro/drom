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

let cmd_name = "build"

let action ~args () =
  let (p : Types.project) = Build.build ~args () in
  let n = ref 0 in
  List.iter
    (fun package ->
      match package.kind with
      | Library -> ()
      | Virtual -> ()
      | Program ->
        if Sys.file_exists package.name then Sys.remove package.name;
        let src = "_build/default" // package.dir // "main.exe" in
        if Sys.file_exists src then (
          let s = EzFile.read_file src in
          EzFile.write_file package.name s;
          incr n;
          Unix.chmod package.name 0o755
        ) )
    p.packages;
  if !Globals.verbosity > 0 then
    Printf.eprintf "\nBuild OK%s\n%!"
      ( if !n > 0 then
        Printf.sprintf " ( %d command%s generated )" !n
          ( if !n > 1 then
            "s"
          else
            "" )
      else
        "" )

let cmd =
  let args, specs = Build.build_args () in
  EZCMD.sub cmd_name
    (fun () -> action ~args ())
    ~args:specs ~doc:"Build a project"
    ~man:
      [ `S "DESCRIPTION";
        `Blocks
          [ `P "This command performs the following actions:";
            `I
              ( "1.",
                "Create a local opam switch. The argument $(b,--switch SWITCH) \
                 can be used to make the local switch a link to a global \
                 switch. The argument $(b,--local) can be used to force a \
                 local switch to be created." );
            `I
              ( "2.",
                "Check that the OCaml version is at least the $(b,min-edition) \
                 specified in the project. If OCaml is not installed, use the \
                 $(b,--edition VERSION) argument or the $(b,edition) field \
                 specified in the project to install OCaml." );
            `I
              ( "3.",
                "Install all the dependencies in the opam switch. If the \
                 argument $(b,--locked) was specified, use the \
                 $(b,${package}-deps.opam.locked) file in the project to get \
                 exact dependencies." );
            `I
              ( "4.",
                "Build the project by calling $(b,opam exec -- dune build \
                 @install)" );
            `I
              ( "5.",
                "If build was ok, copy executable in the top directory of the \
                 project" )
          ]
      ]
