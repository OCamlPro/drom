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
open EzCompat
open Ez_file.V1
open EzFile.OP

let cmd_name = "new"

let print_dir name dir =
  let open EzPrintTree.TYPES in
  let rec iter name dir =
    let files = Sys.readdir dir in
    Array.sort compare files;
    let files = Array.to_list files in
    Branch
      ( name,
        List.map
          (fun file ->
            let dir = dir // file in
            if Sys.is_directory dir then
              iter (file ^ "/") dir
            else
              let file =
                match file with
                | ".drom" -> ".drom             (drom state, do not edit)"
                | "drom.toml" ->
                  "drom.toml    <────────── project config EDIT !"
                | "package.toml" ->
                  "package.toml    <────────── package config EDIT !"
                | _ -> file
              in
              Branch (file, []) )
          (List.filter
             (function
               | ".git"
               | "_drom"
               | "_build" ->
                 false
               | _ -> true )
             files ) )
  in
  let tree = iter name dir in
  EzPrintTree.print_tree tree

let rec find_project_package name packages =
  match packages with
  | [] -> Error.raise "Cannot find main package %S" name
  | package :: packages ->
    if package.name = name then
      package
    else
      find_project_package name packages

let create_project ~config ~name ~skeleton ~dir ~inplace ~update_args =
  let share_args = update_args.arg_share in
  let skeleton_name =
    match skeleton with
    | None -> "program"
    | Some skeleton -> skeleton
  in
  let license =
    match config.config_license with
    | None -> Globals.key_LGPL2
    | Some license -> license
  in
  let dir =
    match dir with
    | None -> "src" // name
    | Some dir -> dir
  in
  Printf.eprintf "Creating project %S with skeleton %S, license %S\n" name
    skeleton_name license;
  Printf.eprintf "  and sources in %s:\n%!" dir;

  let share = Share.load ~share_args () in
  let skeleton = Skeleton.lookup_project share skeleton_name in

  if Globals.verbose 2 then
    Printf.eprintf "Skeleton %s = %s\n%!" skeleton_name
      (Skeleton.to_string skeleton);

  let package, packages =
    let package = Package.create ~kind:Virtual ~name ~dir in
    (package, [ package ])
  in
  let author = Project.find_author config in
  let copyright =
    match config.config_copyright with
    | Some copyright -> Some copyright
    | None -> Some author
  in
  let gendep_for_test =
    { depversions = [];
      depname = None;
      deptest = true;
      depdoc = false;
      depopt = false;
      dep_pin = None;
    }
  in
  let p =
    { Globals.dummy_project with
      project_create = true;
      package;
      packages;
      project_share_repo = Some ( Share.share_repo_default () );
      project_share_version = Some share.share_version ;
      skeleton = Some skeleton_name;
      authors = [ author ];
      synopsis = Globals.default_synopsis ~name;
      description = Globals.default_description ~name;
      tools =
        [ ("ocamlformat", { gendep_for_test with depversions = [ Eq "0.15" ] });
          ("ppx_expect", gendep_for_test);
          ("ppx_inline_test", gendep_for_test);
          ("odoc", { gendep_for_test with depdoc = true })
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
      ci_systems = Globals.default_ci_systems;
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
    Unix.chdir name
  );

  (* first, resolve project skeleton *)
  let rec iter_skeleton list =
    match list with
    | [] -> (p, None)
    | content :: super ->
       let p, _ = iter_skeleton super in
       let content = Subst.project (Subst.state () share p) content in
       Toml.with_override (fun () ->
           let p = Project.of_string
                     ~msg:"drom.toml template" ~default:p content in
           (p, Some content) )
  in
  Printf.eprintf "Project drom-version: %s\n%!" p.project_drom_version ;
  Printf.eprintf "len %d\n%!" (List.length skeleton.skeleton_toml);
  let p, p_content = iter_skeleton skeleton.skeleton_toml in
  Printf.eprintf "Project drom-version: %s\n%!" p.project_drom_version ;

  (* second, resolve package skeletons *)
  let rec iter_skeleton package list =
    match list with
    | [] -> package
    | content :: super ->
       let package = iter_skeleton package super in
       let flags = Skeleton.default_flags "package.toml" in
       let content = Skeleton.subst_package_file flags content
                       (Subst.state () share package) in
       Toml.with_override (fun () ->
           let package =
             Package.of_string ~msg:"package.toml template" ~default:p content
           in
           package )
  in
  let packages =
    List.map
      (fun package ->
        let skeleton = Misc.package_skeleton package in
        Printf.eprintf "Using skeleton %S for package %S\n%!" skeleton
          package.name;
        let skeleton = Skeleton.lookup_package share skeleton in
        iter_skeleton package skeleton.skeleton_toml )
      p.packages
  in

  (* create new project with correct packages *)
  let project =
    { p with package = find_project_package p.package.name packages; packages }
  in
  List.iter (fun p -> p.project <- project) packages;

  (* third, extract project again, but with knowledge of packages *)
  let p =
    match p_content with
    | None -> project
    | Some content ->
       Toml.with_override (fun () ->
           Project.of_string ~msg:"drom.toml template" ~default:project content )
  in

  (* Set fields that are not in templates *)
  let p = {
      p with
      project_create = true ;
      project_share_repo = Some ( Share.share_repo_default () );
      project_share_version = Some share.share_version ;
    } in

  Update.update_files share ~warning:false ~twice:true ~git:true ~update_args p;
  let tree = print_dir (name ^ "/") "." in
  Printf.eprintf "%s%!" tree ;
  Update.display_create_warning p

(* lookup for "drom.toml" and update it *)
let action ~skeleton ~name ~inplace ~dir ~update_args =
  let share_args = update_args.arg_share in
  match name with
  | None ->
      let share = Share.load ~share_args () in
      Printf.eprintf
        {|You must specify the name of the project to create:

drom new PROJECT --skeleton SKELETON

Available skeletons are: %s
|}
        ( Skeleton.project_skeletons share
          |> List.map (fun s -> s.skeleton_name)
          |> String.concat " " );
      exit 2
  | Some name -> (
      let config = Config.get () in
      let project = Project.find () in
      match project with
      | None -> create_project ~config ~name ~skeleton ~dir ~inplace ~update_args
      | Some (p, _) ->
          Error.raise
            "Cannot create a project within another project %S. Maybe you want to \
             use 'drom package PACKAGE --new' instead?"
            p.package.name )

let cmd =
  let project_name = ref None in
  let inplace = ref false in
  let skeleton = ref None in
  let dir = ref None in
  let update_args, update_specs = Update.args ~set_share:true () in
  update_args.arg_upgrade <- true;
  EZCMD.sub cmd_name
    ~args:
      ( update_specs
      @ [ ( [ "dir" ],
            Arg.String (fun s -> dir := Some s),
            EZCMD.info ~docv:"DIRECTORY"
              "Dir where package sources are stored (src by default)" );
          ( [ "library" ],
            Arg.Unit (fun () -> skeleton := Some "library"),
            EZCMD.info "Project contains only a library" );
          ( [ "program" ],
            Arg.Unit (fun () -> skeleton := Some "program"),
            EZCMD.info "Project contains only a program" );
          ( [ "virtual" ],
            Arg.Unit (fun () -> skeleton := Some "virtual"),
            EZCMD.info "Package is virtual, i.e. no code" );
          ( [ "skeleton" ],
            Arg.String (fun s -> skeleton := Some s),
            EZCMD.info ~docv:"SKELETON"
              "Create project using a predefined skeleton or one specified in \
               ~/.config/drom/skeletons/" );
          ( [ "inplace" ],
            Arg.Set inplace,
            EZCMD.info "Create project in the the current directory" );
          ( [],
            Arg.Anon (0, fun name -> project_name := Some name),
            EZCMD.info ~docv:"PROJECT" "Name of the project" )
        ] )
    ~doc:"Create a new project"
    (fun () ->
       action
         ~name:!project_name
         ~skeleton:!skeleton
         ~dir:!dir
         ~inplace:!inplace
        ~update_args )
    ~man:
      [ `S "DESCRIPTION";
        `Blocks
          [ `P
              "This command creates a new project, with name $(b,PROJECT) in a \
               directory $(b,PROJECT) (unless the $(b,--inplace) argument was \
               provided)."
          ];
        `S "EXAMPLE";
        `P
          "The following command creates a project containing library \
           $(b,my_lib) in $(b,src/my_lib):";
        `Pre {|
drom new my_lib --skeleton library
|};
        `P
          "The following command creates a project containing a library \
           $(b,hello_lib) in $(b,src/hello_lib) and a program $(b,hello) in \
           $(b,src/hello) calling the library:";
        `Pre {|
drom new hello --skeleton program
|}
      ]
