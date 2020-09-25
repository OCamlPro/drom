(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Types
open Ezcmd.TYPES

let cmd_name = "project"

(* lookup for "drom.toml" and update it *)
let action ~skeleton ~mode ~upgrade ~promote_skip
    ~dir =
  let project = Project.find () in
  match project with
  | None ->
      Error.raise "No project found. Maybe you need to create a \
                   project first with 'drom new PROJECT'"
  | Some (p, _) ->

      let _sk = Skeleton.lookup_project skeleton in

      let upgrade =
        if p.skeleton <> skeleton then begin
          p.skeleton <- skeleton;
          true
        end else
          upgrade
      in
      if dir <> None then
        Error.raise "Option --dir is not available for update";
      Update.update_files ~create:false ?mode ~upgrade ~promote_skip ~git:true p

let cmd =
  let mode = ref None in
  let upgrade = ref false in
  let promote_skip = ref false in
  let skeleton = ref None in
  let dir = ref None in
  {
    cmd_name;
    cmd_action =
      (fun () ->
         action ~skeleton:!skeleton ~mode:!mode
           ~upgrade:!upgrade ~promote_skip:!promote_skip ~dir:!dir
           );
    cmd_args =
      [
        ( [ "dir" ],
          Arg.String
            (fun s ->
               dir := Some s;
               upgrade := true),
          Ezcmd.info "Dir where package sources are stored (src by default)" );
        ( [ "library" ],
          Arg.Unit
            (fun () ->
               skeleton := Some "library";
               upgrade := true),
          Ezcmd.info "Project contains only a library" );
        ( [ "program" ],
          Arg.Unit
            (fun () ->
               skeleton := Some "program";
               upgrade := true),
          Ezcmd.info "Project contains only a program" );
        ( [ "virtual" ],
          Arg.Unit
            (fun () ->
               skeleton := Some "virtual";
               upgrade := true),
          Ezcmd.info "Package is virtual, i.e. no code" );
        ( [ "binary" ],
          Arg.Unit
            (fun () ->
               mode := Some Binary;
               upgrade := true),
          Ezcmd.info "Compile to binary" );
        ( [ "javascript" ],
          Arg.Unit
            (fun () ->
               mode := Some Javascript;
               upgrade := true),
          Ezcmd.info "Compile to javascript" );
        ( [ "skeleton" ],
          Arg.String (fun s -> skeleton := Some s),
          Ezcmd.info
            "Create project using a predefined skeleton or one \
             specified in ~/.config/drom/skeletons/" );
        ([ "upgrade" ], Arg.Set upgrade, Ezcmd.info "Upgrade drom.toml file");
        ( [ "promote-skip" ],
          Arg.Unit
            (fun () ->
               promote_skip := true;
               upgrade := true),
          Ezcmd.info "Promote skipped files to skip field" );
      ];
    cmd_man = [];
    cmd_doc = "Create an initial project";
  }
