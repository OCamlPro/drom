(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

let main () =

  let commands =
    [
      CommandNew.cmd ;
      CommandBuild.cmd ;
      CommandRun.cmd ;
      CommandInstall.cmd ;
      CommandUninstall.cmd ;
      CommandClean.cmd ;
      CommandFmt.cmd ;
      CommandDevDeps.cmd ;
      CommandBuildDeps.cmd ;
      CommandDoc.cmd ;
      CommandSphinx.cmd ;
      CommandTest.cmd ;
      CommandPublish.cmd ;
    ]
  in
  Printexc.record_backtrace true;
  begin
    match Sys.argv with
    | [| _ ; "--version" |] ->
      Printf.printf "%s\n%!" Globals.version
    | [| _ ; "--about" |] ->
      Printf.printf "%s\n%!" Globals.about
    | _ ->
      (*    OpambinMisc.global_log "args: %s"
            (String.concat " " (Array.to_list Sys.argv)); *)
      try
        Ezcmd.main_with_subcommands
          ~name:Globals.command
          ~version:Globals.version
          ~doc:"Create and manage an OCaml project"
          ~man:[]
          commands
      with
      | Types.Error s ->
        Printf.eprintf "Error: %s\n%!" s ;
        exit 2
      | exn ->
        let bt = Printexc.get_backtrace () in
        let error = Printexc.to_string exn in
        Printf.eprintf "fatal exception %s\n%s\n%!" error bt ;
        exit 2
  end
