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
open EzCompat

let cmd_name = "project"

let create_project ~config ~name ~skeleton ~kind ~mode ~dir ~inplace =
  let license =
    match config.config_license with
    | None -> License.LGPL2.key
    | Some license -> license
  in
  let kind = match kind with None -> Program | Some kind -> kind in
  let dir = match dir with None -> "src" | Some dir -> dir in
  let package = Project.create_package ~kind ~name ~dir in
  let author = Project.find_author config in
  let copyright =
    match config.config_copyright with
    | Some copyright -> Some copyright
    | None -> Some author
  in
  let p =
    {
      package;
      packages = [ package ];
      skeleton;
      version = "0.1.0";
      edition = Globals.current_ocaml_edition;
      min_edition = Globals.current_ocaml_edition;
      mode = Binary;
      authors = [ author ];
      synopsis = Globals.default_synopsis ~name;
      description = Globals.default_description ~name;
      dependencies = [];
      tools =
        [
          ( "ocamlformat",
            { depversions = []; depname = None; deptest = true; depdoc = false }
          );
          ( "ppx_expect",
            { depversions = []; depname = None; deptest = true; depdoc = false }
          );
          ( "ppx_inline_test",
            { depversions = []; depname = None; deptest = true; depdoc = false }
          );
          ( "odoc",
            { depversions = []; depname = None; deptest = false; depdoc = true }
          );
        ];
      github_organization = config.config_github_organization;
      homepage = None;
      doc_api = None;
      doc_gen = None;
      bug_reports = None;
      license;
      dev_repo = None;
      copyright;
      pack_modules = true;
      skip = [];
      archive = None;
      sphinx_target = None;
      windows_ci = true;
      profiles = StringMap.empty;
      skip_dirs = [];
    }
  in
  package.project <- p;

  if not inplace then (
    if Sys.file_exists name then
      Error.raise "A directory %s already exists" name;
    Printf.eprintf "Creating directory %s\n%!" name;
    EzFile.make_dir ~p:true name;
    Unix.chdir name );
  Update.update_files ~create:true ?mode ~upgrade:true ~promote_skip:false
    ~git:true p

(* lookup for "drom.toml" and update it *)
let action ~skeleton ~project_name ~kind ~mode ~upgrade ~inplace ~promote_skip
    ~dir =
  let config = Lazy.force Config.config in
  let project = Project.find_project () in
  match (project_name, project) with
  | None, None ->
      Error.raise "You must specify the name of the project to create"
  | Some name, None ->
      create_project ~config ~name ~skeleton ~kind ~mode ~dir ~inplace
  | None, Some (p, _) ->
      let upgrade =
        match (p.package.kind, kind) with
        | kind, Some new_kind when kind <> new_kind ->
            p.package.kind <- new_kind;
            true
        | _ -> upgrade
      in
      if dir <> None then Error.raise "Option --dir is not available for update";
      Update.update_files ~create:false ?mode ~upgrade ~promote_skip ~git:true p
  | Some _, Some _ ->
      Error.raise
        "Cannot create a project within another project. Maybe you want to use \
         'drom package PACKAGE --new' ?"

let cmd =
  let project_name = ref None in
  let kind = ref None in
  let mode = ref None in
  let inplace = ref false in
  let upgrade = ref false in
  let promote_skip = ref false in
  let skeleton = ref None in
  let dir = ref None in
  {
    cmd_name;
    cmd_action =
      (fun () ->
        action ~project_name:!project_name ~skeleton:!skeleton ~mode:!mode
          ~kind:!kind ~upgrade:!upgrade ~promote_skip:!promote_skip ~dir:!dir
          ~inplace:!inplace);
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
              kind := Some Library;
              upgrade := true),
          Ezcmd.info "Project contains only a library" );
        ( [ "program" ],
          Arg.Unit
            (fun () ->
              kind := Some Program;
              upgrade := true),
          Ezcmd.info "Project contains only a program" );
        ( [ "virtual" ],
          Arg.Unit
            (fun () ->
              kind := Some Virtual;
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
            "Create project using a skeleton defined in \
             ~/.config/drom/skeletons/" );
        ( [ "inplace" ],
          Arg.Set inplace,
          Ezcmd.info "Create project in the the current directory" );
        ([ "upgrade" ], Arg.Set upgrade, Ezcmd.info "Upgrade drom.toml file");
        ( [ "promote-skip" ],
          Arg.Unit
            (fun () ->
              promote_skip := true;
              upgrade := true),
          Ezcmd.info "Promote skipped files to skip field" );
        ( [],
          Arg.Anon (0, fun name -> project_name := Some name),
          Ezcmd.info "Name of the project" );
      ];
    cmd_man = [];
    cmd_doc = "Create an initial project";
  }
