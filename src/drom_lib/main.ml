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

let main () =
  let commands =
    [ CommandNew.cmd;
      CommandProject.cmd;
      CommandPackage.cmd;
      CommandBuild.cmd;
      CommandRun.cmd;
      CommandInstall.cmd;
      CommandUninstall.cmd;
      CommandClean.cmd;
      CommandFmt.cmd;
      CommandDevDeps.cmd;
      CommandBuildDeps.cmd;
      CommandDoc.cmd;
      CommandSphinx.cmd;
      CommandTest.cmd;
      CommandPublish.cmd;
      CommandUpdate.cmd;
      CommandTree.cmd;
      CommandPromote.cmd
    ]
  in
  let common_args =
    [ ( [ "v"; "verbose" ],
        Arg.Unit (fun () -> incr Globals.verbosity),
        Ezcmd.info "Increase verbosity level" )
    ]
  in
  let commands =
    List.map
      (fun sub -> { sub with cmd_args = common_args @ sub.cmd_args })
      commands
  in
  Printexc.record_backtrace true;
  match Sys.argv with
  | [| _; "--version" |] -> Printf.printf "%s\n%!" Version.version
  | [| _; "--about" |] -> Printf.printf "%s\n%!" Globals.about
  | _ -> (
    (* OpambinMisc.global_log "args: %s"
       (String.concat " " (Array.to_list Sys.argv)); *)
    try
      Ezcmd.main_with_subcommands ~name:Globals.command ~version:Version.version
        ~doc:"Create and manage an OCaml project" ~man:[] commands
    with
    | Error.Error s ->
      Printf.eprintf "Error: %s\n%!" s;
      exit 2
    | exn ->
      let bt = Printexc.get_backtrace () in
      let error = Printexc.to_string exn in
      Printf.eprintf "fatal exception %s\n%s\n%!" error bt;
      exit 2 )
