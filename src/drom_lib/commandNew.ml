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
open Ezcmd.V2
open EZCMD.TYPES
open EzCompat
open EzFile.OP

let cmd_name = "new"


let print_dir name dir =
  let open EzPrintTree in
  let rec iter name dir =
    let files = Sys.readdir dir in
    Array.sort compare files;
    let files = Array.to_list files in
    Branch (name,
            List.map (fun file ->
                let dir = dir // file in
                if Sys.is_directory dir then
                  iter (file ^ "/") dir
                else
                  let file =
                    match file with
                    | ".drom" -> ".drom             (drom state, do not edit)"
                    | "drom.toml" -> "drom.toml    <────────── project config EDIT !"
                    | "package.toml" -> "package.toml    <────────── package config EDIT !"
                    | _ -> file
                  in
                  Branch (file, [])
              )
              (List.filter (function
                   | ".git"
                   | "_drom"
                   | "_build"
                     -> false
                   | _ -> true
                 ) files ))
  in
  let tree = iter name dir in
  print_tree "" tree

let rec find_project_package name packages =
  match packages with
  | [] -> Error.raise "Cannot find main package %S" name
  | package :: packages ->
      if package.name = name then package else
        find_project_package name packages

let create_project ~config ~name ~skeleton ~mode ~dir ~inplace ~args =
  let skeleton_name = match skeleton with
    | None -> "program"
    | Some skeleton -> skeleton
  in
  let license =
    match config.config_license with
    | None -> License.key_LGPL2
    | Some license -> license
  in
  let dir =
    match dir with
    | None -> "src" // name
    | Some dir -> dir
  in
  Printf.eprintf
    "Creating project %S with skeleton %S, license %S\n"
    name skeleton_name license;
  Printf.eprintf
    "  and sources in %s:\n%!" dir;
  let skeleton = Skeleton.lookup_project ( Some skeleton_name ) in

  let package, packages =
    let package = Project.create_package ~kind:Virtual ~name ~dir in
    (package, [ package ])
  in
  let author = Project.find_author config in
  let copyright =
    match config.config_copyright with
    | Some copyright -> Some copyright
    | None -> Some author
  in
  let p =
    { Project.dummy_project with
      package;
      packages;
      skeleton = Some skeleton_name;
      authors = [ author ];
      synopsis = Globals.default_synopsis ~name;
      description = Globals.default_description ~name;
      tools =
        [ ( "ocamlformat",
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
          )
        ];
      github_organization = config.config_github_organization;
      homepage = None;
      doc_api = None;
      doc_gen = None;
      bug_reports = None;
      license;
      dev_repo = None;
      copyright;
      skip = [];
      archive = None;
      sphinx_target = None;
      odoc_target = None;
      ci_systems = Misc.default_ci_systems;
      profiles = StringMap.empty;
      skip_dirs = [];
      fields = StringMap.empty
    }
  in
  package.project <- p;

  if not inplace then (
    if Sys.file_exists name then
      Error.raise "A directory %s already exists" name;
    Printf.eprintf "Creating directory %s\n%!" name;
    EzFile.make_dir ~p:true name;
    Unix.chdir name
  );

  (* first, resolve project skeleton *)
  let rec iter_skeleton list =
    match list with
    | [] -> (p, None)
    | content :: super ->
        let p,_ = iter_skeleton super in
        let content = Subst.project () p content in
        Project.of_string ~msg:"toml template" ~default:p content, Some content
  in
  let p, p_content = iter_skeleton skeleton.skeleton_toml in

  (* second, resolve package skeletons *)

  let rec iter_skeleton package list =
    match list with
    | [] -> package
    | content :: super ->
        let package = iter_skeleton package super in
        let flags = Skeleton.default_flags "package.toml" in
        let content = Skeleton.subst_package_file flags content package in
        match EzToml.from_string content with
        | `Ok table ->
            Project.package_of_toml ~default:p table
        | `Error (s, loc) ->
            Error.raise "Could not parse:\n<<<\n%s>>>\n %s at %s"
              content s
              (EzToml.string_of_location loc)

  in
  let packages = List.map (fun package ->
      let skeleton = Misc.package_skeleton package in
      Printf.eprintf "Using skeleton %S for package %S\n%!"
        skeleton package.name;
      let skeleton = Skeleton.lookup_package skeleton in
      iter_skeleton package skeleton.skeleton_toml) p.packages in

  (* create new project with correct packages *)
  let project = {
    p with
    package = find_project_package p.package.name packages;
    packages }
  in
  List.iter (fun p -> p.project <- project) packages;

  (* third, extract project again, but with knowledge of packages *)
  let p = match p_content with
    | None -> project
    | Some content ->
        Project.of_string ~msg:"toml template" ~default:project content
  in

  Update.update_files ~twice:true ~create:true ?mode ~git:true ~args p;
  print_dir (name ^ "/") "."

(* lookup for "drom.toml" and update it *)
let action ~skeleton ~name ~mode ~inplace ~dir ~args =
  match name with
  | None ->
      Printf.eprintf {|You must specify the name of the project to create:

drom new PROJECT --skeleton SKELETON

Available skeletons are: %s
|} (Skeleton.project_skeletons ()
    |> List.map (fun s -> s.skeleton_name)
    |> String.concat " ");
      exit 2

  | Some name -> (
    let config = Lazy.force Config.config in
    let project = Project.find () in
    match project with
    | None -> create_project ~config ~name ~skeleton ~mode ~dir ~inplace ~args
    | Some (p, _) ->
      Error.raise
        "Cannot create a project within another project %S. Maybe you want to \
         use 'drom package PACKAGE --new' instead?"
        p.package.name )

let cmd =
  let project_name = ref None in
  let mode = ref None in
  let inplace = ref false in
  let skeleton = ref None in
  let dir = ref None in
  let args, specs = Update.update_args () in
  args.arg_upgrade <- true;
  EZCMD.sub cmd_name
    ~args:
      (
        specs
        @ [ ( [ "dir" ],
              Arg.String (fun s -> dir := Some s),
              EZCMD.info ~docv:"DIRECTORY"
                "Dir where package sources are stored (src by default)"
            );
            ( [ "library" ],
              Arg.Unit (fun () -> skeleton := Some "library"),
              EZCMD.info "Project contains only a library" );
            ( [ "program" ],
              Arg.Unit (fun () -> skeleton := Some "program"),
              EZCMD.info "Project contains only a program" );
            ( [ "virtual" ],
              Arg.Unit (fun () -> skeleton := Some "virtual"),
              EZCMD.info "Package is virtual, i.e. no code" );
            ( [ "binary" ],
              Arg.Unit (fun () -> mode := Some Binary),
              EZCMD.info "Compile to binary" );
            ( [ "javascript" ],
              Arg.Unit (fun () -> mode := Some Javascript),
              EZCMD.info "Compile to javascript" );
            ( [ "skeleton" ],
              Arg.String (fun s -> skeleton := Some s),
              EZCMD.info
                ~docv:"SKELETON"
                "Create project using a predefined skeleton or one specified in \
                 ~/.config/drom/skeletons/" );
            ( [ "inplace" ],
              Arg.Set inplace,
              EZCMD.info "Create project in the the current directory" );
            ( [],
              Arg.Anon (0, fun name -> project_name := Some name),
              EZCMD.info ~docv:"PROJECT" "Name of the project" )
          ])
    ~doc:"Create a new project"
    (fun () ->
       action ~name:!project_name ~skeleton:!skeleton ~mode:!mode ~dir:!dir
         ~inplace:!inplace ~args)
    ~man: [
      `S "DESCRIPTION";
      `Blocks [
        `P "This command creates a new project, with name $(b,PROJECT) in a directory $(b,PROJECT) (unless the $(b,--inplace) argument was provided).";

      ];
      `S "EXAMPLE";
      `P "The following command creates a project containing library $(b,my_lib) in $(b,src/my_lib):";
      `Pre {|
drom new my_lib --skeleton library
|};
      `P "The following command creates a project containing a library $(b,hello_lib) in $(b,src/hello_lib) and a program $(b,hello) in $(b,src/hello) calling the library:";
      `Pre {|
drom new hello --skeleton program
|}
    ]
