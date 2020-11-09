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

let cmd_name = "init"

let init_project ~config ~name ~skeleton ~mode ~dir ~args =

  (* all opam files we found *)
  let opam_files = Opam.get_files () in

  (* try to extract the field `field` using the function `f` from one opam file, if it fails, then use the next opam file. If there's no more opam file, use `default` *)
  let find_in_opam_files f field default =
    let rec aux = function
    | [] -> default
    | file::files ->
      let file = OpamParser.file file in
      let file = file.file_contents in
      begin match Misc.option_bind (Opam.get_field field file) f with
      | None -> aux files
      | Some v -> v
      end
    in aux opam_files
  in

  let extract_string = function
    | OpamParserTypes.String (_pos, s) -> Some s
    | _v -> None
  in

  let wrap_extract_string = function
    | OpamParserTypes.String (_pos, s) -> Some (Some s)
    | _v -> None
  in

  let wrap_extract_string_list = function
    | OpamParserTypes.List (_pos, l) ->
        begin try Some (List.map (function | OpamParserTypes.String (_pos, s) -> s | _v -> raise Exit) l)
        with Exit -> None end
    | _v -> None
  in

  let dir = Misc.option_value dir ~default:("src" // name) in
  let package, packages =
    let package = Project.create_package ~kind:Virtual ~name ~dir in
    (package, [ package ])
  in
  let license =
    let default = Misc.option_value config.config_license ~default:License.default in
    find_in_opam_files
    (fun x -> Misc.option_bind (extract_string x) License.key_from_name)
    "license" default
  in
  let authors = find_in_opam_files wrap_extract_string_list "authors" [Project.find_author config] in
  let copyright =  Some (Misc.option_value config.config_copyright ~default:(String.concat ", " authors)) in
  let generators = [ "ocamllex"; "ocamlyacc" ] in
  let synopsis = find_in_opam_files extract_string "synopsis" (Globals.default_synopsis ~name) in
  let description = find_in_opam_files extract_string "description" (Globals.default_description ~name) in
  let homepage = find_in_opam_files wrap_extract_string "homepage" None in
  let bug_reports = find_in_opam_files wrap_extract_string "bug-reports" None in
  let dev_repo = find_in_opam_files wrap_extract_string "dev-repo" None in
  let archive = find_in_opam_files wrap_extract_string "archive" None in
  let doc_gen = find_in_opam_files wrap_extract_string "doc" None in

  let p =
    { Project.dummy_project with
      package;
      packages;
      skeleton;
      authors;
      synopsis;
      description;
      generators;
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
      homepage;
      doc_api = None;
      doc_gen;
      bug_reports;
      license;
      dev_repo;
      copyright;
      pack_modules = true;
      skip = [];
      archive;
      sphinx_target = None;
      odoc_target = None;
      windows_ci = true;
      profiles = StringMap.empty;
      skip_dirs = [];
      fields = StringMap.empty
    }
  in
  package.project <- p;

  let rec iter_skeleton list =
    match list with
    | [] -> p
    | content :: super ->
      let p = iter_skeleton super in
      let content = Subst.project () p content in
      let res = Project.of_string ~msg:"toml template" ~default:p content in
      res
  in
  let skeleton = Skeleton.lookup_project skeleton in
  let p = iter_skeleton skeleton.skeleton_toml in
  Update.update_files ~create:true ?mode ~promote_skip:false ~git:true ~args p

(* init the project if "drom.toml" doesn't alreay exist, fail otherwise *)
let action ~skeleton ~name ~mode ~dir ~args =
    let config = Lazy.force Config.config in
    let project = Project.find () in
    match project with
    | None -> init_project ~config ~name ~skeleton ~mode ~dir ~args
    | Some (p, _) ->
      Error.raise
        "Cannot create a project within another project %S. Maybe you want to \
         use 'drom package PACKAGE --new' instead?"
        p.package.name

let cmd =
  let project_name = Filename.basename @@ Sys.getcwd () in
  let mode = ref None in
  let skeleton = ref None in
  let dir = ref None in
  let args, specs = Update.update_args () in
  args.arg_upgrade <- true;
  { cmd_name;
    cmd_action =
      (fun () ->
        action ~name:project_name ~skeleton:!skeleton ~mode:!mode ~dir:!dir
           ~args);
    cmd_args =
      specs
      @ [ ( [ "dir" ],
            Arg.String (fun s -> dir := Some s),
            Ezcmd.info "Dir where package sources are stored (src by default)"
          );
          ( [ "library" ],
            Arg.Unit (fun () -> skeleton := Some "library"),
            Ezcmd.info "Project contains only a library" );
          ( [ "program" ],
            Arg.Unit (fun () -> skeleton := Some "program"),
            Ezcmd.info "Project contains only a program" );
          ( [ "virtual" ],
            Arg.Unit (fun () -> skeleton := Some "virtual"),
            Ezcmd.info "Package is virtual, i.e. no code" );
          ( [ "binary" ],
            Arg.Unit (fun () -> mode := Some Binary),
            Ezcmd.info "Compile to binary" );
          ( [ "javascript" ],
            Arg.Unit (fun () -> mode := Some Javascript),
            Ezcmd.info "Compile to javascript" );
          ( [ "skeleton" ],
            Arg.String (fun s -> skeleton := Some s),
            Ezcmd.info
              (Format.sprintf "Create project using a predefined skeleton or one specified in \
               %s/skeletons/" Globals.config_dir))
        ];
    cmd_man = [];
    cmd_doc = "Create a new drom project in an existing directory"
  }
