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
      CommandList.cmd;
      CommandTest.cmd;
      CommandPublish.cmd;
      CommandUpdate.cmd;
      CommandTree.cmd;
      CommandPromote.cmd;
      CommandLock.cmd;
      CommandDep.cmd;
      CommandOpamPlugin.cmd;
      CommandConfig.cmd;
      CommandTop.cmd;
    ]
  in
  let common_args =
    [
      [ "v"; "verbose" ],
      Arg.Unit (fun () -> incr Globals.verbosity),
      EZCMD.info "Increase verbosity level" ;
      [ "q"; "quiet" ],
      Arg.Unit (fun () -> Globals.verbosity := 0),
      EZCMD.info "Set verbosity level to 0";
    ]
  in
  Printexc.record_backtrace true;
  let args = Array.to_list Sys.argv in
  let rec iter_initial_args args =
    match args with
    | [] -> []
    | [ "--version" ] ->
        Printf.printf "%s\n%!" Version.version;
        exit 0
    | [ "--about" ] ->
        Printf.printf "%s\n%!" Globals.about;
        exit 0
    | ( "-v" | "--verbose" ) :: args ->
        incr Globals.verbosity;
        iter_initial_args args
    | ( "-q" | "--quiet" ) :: args ->
        Globals.verbosity := 0;
        iter_initial_args args
    | [ "rst" ] ->
        Printf.printf "%s%!" ( EZCMD.to_rst commands common_args );
        exit 0
    | _ -> args
  in

  let args = iter_initial_args (List.tl args ) in
  let argv = Array.of_list ( Sys.argv.(0) :: args ) in
  (* OpambinMisc.global_log "args: %s"
         (String.concat " " (Array.to_list Sys.argv)); *)
  try
    EZCMD.main_with_subcommands ~name:Globals.command ~version:Version.version
      ~doc:"Create and manage an OCaml project" ~man:[] ~argv commands
      ~common_args;
  with
  | Error.Error s ->
      Printf.eprintf "Error: %s\n%!" s;
      exit 2
  | exn ->
      let bt = Printexc.get_backtrace () in
      let error = Printexc.to_string exn in
      Printf.eprintf "fatal exception %s\n%s\n%!" error bt;
      exit 2
