(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Ez_file.V1
open EzFile.OP

let command = "drom"

let about =
  Printf.sprintf "%s %s by OCamlPro SAS <contact@ocamlpro.com>" command
    Version.version

let min_ocaml_edition = "4.07.0"

let current_ocaml_edition = "4.13.0"

let current_dune_version = "2.8.0"

let default_synopsis ~name = Printf.sprintf "The %s project" name

let default_description ~name =
  Printf.sprintf "This is the description\nof the %s OCaml project\n" name

let drom_dir = "_drom"

let build_dir = "_build"

let drom_file = "drom.toml"

module App_id = struct
  let qualifier = "com"

  let organization = "OCamlPro"

  let application = "drom"
end

module Base_dirs = Directories.Base_dirs ()

module Project_dirs = Directories.Project_dirs (App_id)

let home_dir =
  match Base_dirs.home_dir with
  | None ->
    Format.eprintf
      "Error: can't compute HOME path, make sure it is well defined !@.";
    exit 2
  | Some home_dir -> home_dir

let config_dir =
  match Project_dirs.config_dir with
  | None ->
    Format.eprintf
      "Error: can't compute configuration path, make sure your HOME and other \
       environment variables are well defined !@.";
    exit 2
  | Some config_dir -> config_dir

let min_drom_version = "0.1"

let verbosity = ref 1

let opam_switch_prefix =
  match Sys.getenv "OPAM_SWITCH_PREFIX" with
  | exception Not_found -> None
  | switch_dir -> Some switch_dir

let find_ancestor_file file f =
  let dir = Sys.getcwd () in
  let rec iter dir path =
    let drom_file = dir // file in
    if Sys.file_exists drom_file then
      Some (f ~dir ~path)
    else
      let updir = Filename.dirname dir in
      if updir <> dir then
        iter updir (Filename.basename dir // path)
      else
        None
  in
  iter dir ""

let opam_root =
  lazy
    ( try Sys.getenv "OPAMROOT" with
    | Not_found -> home_dir // ".opam" )

let opam_root () = Lazy.force opam_root

let verbose_subst =
  try
    ignore (Sys.getenv "DROM_VERBOSE_SUBST");
    true
  with
  | Not_found -> false

let verbose i = !verbosity >= i

let editor =
  match Sys.getenv "EDITOR" with
  | exception Not_found -> "emacs"
  | editor -> editor

let main_branch = "master"

let key_LGPL2 = "LGPL2"

let default_ci_systems =
  [ "ubuntu-latest"; "macos-latest"; "windows-latest" ]

open EzCompat
open Types

let rec dummy_project =
  { package = dummy_package;
    packages = [];
    project_share_repo = None;
    project_share_version = None;
    skeleton = None;
    edition = current_ocaml_edition;
    project_drom_version = min_drom_version;
    min_edition = min_ocaml_edition;
    github_organization = None;
    homepage = None;
    license = key_LGPL2;
    copyright = None;
    bug_reports = None;
    dev_repo = None;
    doc_gen = None;
    doc_api = None;
    skip = [];
    version = "0.1.0";
    authors = [];
    synopsis = "dummy_project.synopsis ";
    description = "dummy_project.description";
    dependencies = [];
    tools = [];
    archive = None;
    sphinx_target = None;
    odoc_target = None;
    ci_systems = default_ci_systems;
    profiles = StringMap.empty;
    skip_dirs = [];
    fields = StringMap.empty;
    profile = None;
    file = None;
    share_dirs = [ "share" ];
    year = (Misc.date ()).Unix.tm_year;
    generators = StringSet.empty;
    menhir_version = None;
    dune_version = current_dune_version ;
    project_create = false ;
  }

and dummy_package =
  { name = "dummy_package";
    dir = "dummy_package.dir";
    project = dummy_project;
    p_file = None;
    p_pack = None;
    kind = Library;
    p_version = None;
    p_authors = None;
    p_synopsis = None;
    p_description = None;
    p_dependencies = [];
    p_tools = [];
    p_pack_modules = None;
    p_gen_version = None;
    p_fields = StringMap.empty;
    p_skeleton = None;
    p_generators = None;
    p_menhir = None;
    p_skip = None;
    p_optional = None;
    p_preprocess = None;
    p_sites = Sites.default;
  }
