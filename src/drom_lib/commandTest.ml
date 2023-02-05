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
open Ez_file.V1
open EzFile.OP

let cmd_name = "test"

let action ~all ~args () =
  let (p : Types.project) = Build.build ~dev_deps:true ~args () in
  let workspace =
    if all then begin
      let root = Globals.opam_root () in
      let oc = open_out "_drom/dune-workspace.dev" in
      Printf.fprintf oc "(lang dune 2.7)\n";
      let files = Sys.readdir root in
      Array.sort compare files;
      Array.iter
        (fun switch ->
          match switch.[0] with
          | '3' .. '9' when not (String.contains switch '+') ->
            if
              switch >= p.min_edition
              && Sys.file_exists (root // switch // ".opam-switch")
            then begin
              Printf.eprintf "Adding switch %s\n%!" switch;
              Printf.fprintf oc "(context (opam (switch %s)))\n" switch
            end
          | _ -> () )
        files;
      close_out oc;
      [ "--workspace"; "_drom/dune-workspace.dev" ]
    end else
      []
  in
  Call.call
    (Array.of_list
       ([ "opam"; "exec"; "--"; "dune"; "build"; "@runtest" ] @ workspace) );
  Printf.eprintf "Tests OK\n%!";
  ()

let cmd =
  let all = ref false in
  let args, specs = Build.build_args () in
  EZCMD.sub cmd_name
    (fun () -> action ~all:!all ~args ())
    ~args:
      ( specs
      @ [ ( [ "all" ],
            Arg.Set all,
            EZCMD.info "Build and run tests on all compatible switches" )
        ] )
    ~doc:"Run tests"
    ~man:
      [ `S "DESCRIPTION";
        `Blocks
          [ `P "This command performs the following actions:";
            `I
              ( "1.",
                "Build the project, installing required test dependencies if \
                 needed" );
            `I
              ( "2.",
                "Run the test command $(b,opam exec -- dune build @runtest)" );
            `P
              "If the $(b,--all) argument was provided, a file \
               $(b,_drom/dune-workspace.dev) is created containing a context \
               for every existing opam switch compatible with the project \
               $(b,min-edition) field, and the tests are run on all of them. \
               Before using this option, you should make sure that \
               dependencies are correctly installed on all of them, using the \
               command $(drom build --switch SWITCH) on every $(b,SWITCH) in \
               the list. Only switches starting with a number and without the \
               $(i,+) character are selected."
          ]
      ]
