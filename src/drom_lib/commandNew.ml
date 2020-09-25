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
open EzFile.OP

let cmd_name = "new"

let create_project ~config ~name ~skeleton ~mode ~dir ~inplace =

  let license =
    match config.config_license with
    | None -> Skel_licenses.LGPL2.key
    | Some license -> license
  in
  let dir = match dir with None -> "src" // name | Some dir -> dir in
  let package, packages =
    let package = Project.create_package ~kind:Virtual ~name ~dir in
    package, [ package ]
  in
  let author = Project.find_author config in
  let copyright =
    match config.config_copyright with
    | Some copyright -> Some copyright
    | None -> Some author
  in
  let generators = [ "ocamllex"; "ocamlyacc" ] in
  let p =
    {
      Project.dummy_project with

      package;
      packages;
      skeleton;
      authors = [ author ];
      synopsis = Globals.default_synopsis ~name;
      description = Globals.default_description ~name;
      generators;
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
      fields = StringMap.empty;
    }
  in
  package.project <- p;


  if not inplace then (
    if Sys.file_exists name then
      Error.raise "A directory %s already exists" name;
    Printf.eprintf "Creating directory %s\n%!" name;
    EzFile.make_dir ~p:true name;
    Unix.chdir name );

  let rec iter_skeleton list =
    match list with
    | [] -> p
    | content :: super ->
        let p = iter_skeleton super in
        let content = Subst.project () p content in
        Project.of_string ~msg:"toml template" ~default:p content
  in

  let skeleton = Skeleton.lookup_project skeleton in
  let p = iter_skeleton skeleton.skeleton_toml in
  Update.update_files ~create:true ?mode ~upgrade:true ~promote_skip:false
    ~git:true p

(* lookup for "drom.toml" and update it *)
let action ~skeleton ~name ~mode ~inplace
    ~dir =
  match name with
  | None -> Error.raise "You must specify the name of the project to create"
  | Some name ->
      let config = Lazy.force Config.config in
      let project = Project.find () in
      match project with
      | None ->
          create_project ~config ~name ~skeleton ~mode ~dir ~inplace
      | Some (p, _) ->
          Error.raise
            "Cannot create a project within another project %S. Maybe \
             you want to use 'drom package PACKAGE --new' instead?"
            p.package.name

let cmd =
  let project_name = ref None in
  let mode = ref None in
  let inplace = ref false in
  let skeleton = ref None in
  let dir = ref None in
  {
    cmd_name;
    cmd_action =
      (fun () ->
         action ~name:!project_name ~skeleton:!skeleton ~mode:!mode
           ~dir:!dir
           ~inplace:!inplace);
    cmd_args =
      [
        ( [ "dir" ],
          Arg.String
            (fun s ->
               dir := Some s;
            ),
          Ezcmd.info "Dir where package sources are stored (src by default)" );
        ( [ "library" ],
          Arg.Unit
            (fun () ->
               skeleton := Some "library";
               ),
          Ezcmd.info "Project contains only a library" );
        ( [ "program" ],
          Arg.Unit
            (fun () ->
               skeleton := Some "program";
               ),
          Ezcmd.info "Project contains only a program" );
        ( [ "virtual" ],
          Arg.Unit
            (fun () ->
               skeleton := Some "virtual";
               ),
          Ezcmd.info "Package is virtual, i.e. no code" );
        ( [ "binary" ],
          Arg.Unit
            (fun () ->
               mode := Some Binary;
               ),
          Ezcmd.info "Compile to binary" );
        ( [ "javascript" ],
          Arg.Unit
            (fun () ->
               mode := Some Javascript;
               ),
          Ezcmd.info "Compile to javascript" );
        ( [ "skeleton" ],
          Arg.String (fun s -> skeleton := Some s),
          Ezcmd.info
            "Create project using a predefined skeleton or one \
             specified in ~/.config/drom/skeletons/" );
        ( [ "inplace" ],
          Arg.Set inplace,
          Ezcmd.info "Create project in the the current directory" );
        ( [],
          Arg.Anon (0, fun name -> project_name := Some name),
          Ezcmd.info "Name of the project" );
      ];
    cmd_man = [];
    cmd_doc = "Create a new project";
  }
