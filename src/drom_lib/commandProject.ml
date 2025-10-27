(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Types
open Ezcmd.V2
open EZCMD.TYPES
open Update
open Ez_file.V1
open EzFile.OP

let cmd_name = "project"

(* lookup for "drom.toml" and update it *)
let action ~skeleton ~edit ~args =
  begin
    match Project.lookup () with
    | None ->
        Error.raise
          "No project found. Maybe you need to create a project first with 'drom \
           new PROJECT'"
    | Some (dir, _) -> (
        if edit then
          let editor = Globals.editor in
          match
            Printf.ksprintf Sys.command "%s '%s'" editor (dir // "drom.toml")
          with
          | 0 -> ()
          | _ -> Error.raise "Editing command returned a non-zero status" )
  end;

  let project = Project.find () in
  match project with
  | None -> assert false
  | Some (p, _) ->
      let args, share_args = args in
      let share = Share.load ~args:share_args ~p () in
      let args = { args with
                   arg_share_version = Some share.share_version ;
                   arg_share_repo = share_args.arg_repo ;
                 }
      in
      let skeleton = match skeleton with
        | None -> Misc.project_skeleton p.skeleton
        | Some skeleton -> skeleton
      in
      (* Used to check that the project exists. *)
      let _sk : skeleton = Skeleton.lookup_project share skeleton in
      let args =
        { args with
          arg_upgrade =
            ( if p.skeleton <> Some skeleton then begin
                  p.skeleton <- Some skeleton;
                  true
                end else
                args.arg_upgrade )
        }
      in
      Update.update_files share ~twice:false ~args ~git:true p

let cmd =
  let skeleton = ref None in
  let update_args, update_specs = Update.args () in
  let share_args, share_specs = Share.args ~set:true () in
  let edit = ref false in
  let args = (update_args, share_args) in
  EZCMD.sub cmd_name
    (fun () -> action
        ~skeleton:!skeleton ~edit:!edit ~args)
    ~args:
      ( update_specs
        @ share_specs
        @ [ ( [ "library" ],
            Arg.Unit
              (fun () ->
                skeleton := Some "library";
                update_args.arg_upgrade <- true ),
            EZCMD.info
              "Project contains only a library. Equivalent to $(b,--skeleton \
               library)" );
          ( [ "program" ],
            Arg.Unit
              (fun () ->
                skeleton := Some "program";
                update_args.arg_upgrade <- true ),
            EZCMD.info
              "Project contains a program. Equivalent to $(b,--skeleton \
               program). The generated project will be composed of a \
               $(i,library) package and a $(i,driver) package calling the \
               $(b,Main.main) of the library." );
          ( [ "virtual" ],
            Arg.Unit
              (fun () ->
                skeleton := Some "virtual";
                update_args.arg_upgrade <- true ),
            EZCMD.info
              "Package is virtual, i.e. no code. Equivalent to $(b,--skeleton \
               virtual)." );
          ( [ "skeleton" ],
            Arg.String
              (fun s ->
                skeleton := Some s;
                update_args.arg_upgrade <- true ),
            EZCMD.info ~docv:"SKELETON"
              "Create project using a predefined skeleton or one specified in \
               ~/.config/drom/skeletons/" );
          ( [ "upgrade" ],
            Arg.Unit (fun () -> update_args.arg_upgrade <- true),
            EZCMD.info "Force upgrade of the drom.toml file from the skeleton"
          );
          ([ "edit" ], Arg.Set edit, EZCMD.info "Edit project description");
        ] )
    ~doc:"Update an existing project"
    ~man:
      [ `S "DESCRIPTION";
        `Blocks
          [ `P
              "This command is used to regenerate the files of a project after \
               updating its description.";
            `P
              "With argument $(b,--upgrade), it can also be used to reformat \
               the toml files, from their skeletons."
          ]
      ]
