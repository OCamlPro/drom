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
open Update

let cmd_name = "project"

(* lookup for "drom.toml" and update it *)
let action ~skeleton ~mode ~args =
  let project = Project.find () in
  match project with
  | None ->
    Error.raise
      "No project found. Maybe you need to create a project first with 'drom \
       new PROJECT'"
  | Some (p, _) ->
    let _sk = Skeleton.lookup_project skeleton in

    let args =
      { args with
        arg_upgrade =
          ( if p.skeleton <> skeleton then begin
            p.skeleton <- skeleton;
            true
          end else
            args.arg_upgrade )
      }
    in
    Update.update_files ~args ~create:false ?mode ~git:true p

let cmd =
  let mode = ref None in
  let skeleton = ref None in
  let args, specs = Update.update_args () in
  { cmd_name;
    cmd_action =
      (fun () ->
        action ~skeleton:!skeleton ~mode:!mode ~args);
    cmd_args =
      specs
      @ [ ( [ "library" ],
            Arg.Unit
              (fun () ->
                skeleton := Some "library";
                args.arg_upgrade <- true),
            Ezcmd.info "Project contains only a library" );
          ( [ "program" ],
            Arg.Unit
              (fun () ->
                skeleton := Some "program";
                args.arg_upgrade <- true),
            Ezcmd.info "Project contains only a program" );
          ( [ "virtual" ],
            Arg.Unit
              (fun () ->
                skeleton := Some "virtual";
                args.arg_upgrade <- true),
            Ezcmd.info "Package is virtual, i.e. no code" );
          ( [ "binary" ],
            Arg.Unit
              (fun () ->
                mode := Some Binary;
                args.arg_upgrade <- true),
            Ezcmd.info "Compile to binary" );
          ( [ "javascript" ],
            Arg.Unit
              (fun () ->
                mode := Some Javascript;
                args.arg_upgrade <- true),
            Ezcmd.info "Compile to javascript" );
          ( [ "skeleton" ],
            Arg.String
              (fun s ->
                skeleton := Some s;
                args.arg_upgrade <- true),
            Ezcmd.info
              "Create project using a predefined skeleton or one specified in \
               ~/.config/drom/skeletons/" );
          ( [ "upgrade" ],
            Arg.Unit (fun () -> args.arg_upgrade <- true),
            Ezcmd.info "Upgrade drom.toml file" );
        ];
    cmd_man = [];
    cmd_doc = "Create an initial project"
  }
