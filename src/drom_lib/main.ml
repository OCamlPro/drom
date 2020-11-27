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
open EZCMD.TYPES

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
      CommandOdoc.cmd;
      CommandDoc.cmd;
      CommandSphinx.cmd;
      CommandTest.cmd;
      CommandPublish.cmd;
      CommandUpdate.cmd;
      CommandTree.cmd;
      CommandPromote.cmd;
      CommandLock.cmd;
      CommandDep.cmd;
    ]
  in
  let common_args =
    [ ( [ "v"; "verbose" ],
        Arg.Unit (fun () -> incr Globals.verbosity),
        EZCMD.info "Increase verbosity level" )
    ]
  in
  Printexc.record_backtrace true;
  match Sys.argv with
  | [| _; "--version" |] -> Printf.printf "%s\n%!" Version.version
  | [| _; "--about" |] -> Printf.printf "%s\n%!" Globals.about
  | [| _; "rst" |] -> CommandRst.action commands common_args
  | _ -> (
    (* OpambinMisc.global_log "args: %s"
       (String.concat " " (Array.to_list Sys.argv)); *)
    try
      EZCMD.main_with_subcommands ~name:Globals.command ~version:Version.version
        ~doc:"Create and manage an OCaml project" ~man:[] commands
        ~common_args
    with
    | Error.Error s ->
      Printf.eprintf "Error: %s\n%!" s;
      exit 2
    | exn ->
      let bt = Printexc.get_backtrace () in
      let error = Printexc.to_string exn in
      Printf.eprintf "fatal exception %s\n%s\n%!" error bt;
      exit 2 )
