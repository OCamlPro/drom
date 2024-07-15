(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open EzCompat (* for StringMap *)

type kind =
  | Program
  | Library
  | Virtual

type version =
  | Lt of string
  | Le of string
  | Eq of string
  | Ge of string
  | Gt of string
  | Version
  | Semantic of int * int * int
  | NoVersion

type dependency =
  {
    (* 'version': a list of space-separated version constraints, where
       "version" is the current version. *)
    depversions : version list;
    (* 'libname': name of version to used as a library *)
    depname : string option;
    (* 'for-test': for dune if different *)
    deptest : bool;
    (* 'for-doc': only for documentation *)
    depdoc : bool;
    (* 'opt': optional dependency *)
    depopt : bool;
    (* 'pin': pin-dependency *)
    dep_pin: string option;
  }

type menhir_parser =
  {
    modules: string list;
    tokens: string option;
    merge_into: string option;
    flags: string list option;
    infer: bool option;
  }

type menhir_tokens =
  {
    modules: string list;
    flags: string list option;
  }

type menhir =
  {
    version: string;
    parser: menhir_parser;
    tokens: menhir_tokens option;
  }

let default_install_destination = ""
let default_install_recursive = false

type install_spec = {
  install_source : string;
  [@key "source"]

  install_destination : string;
  [@default default_install_destination]
  [@key "destination"]

  install_recursive : bool;
  [@default default_install_recursive]
  [@key "recursive"]
}[@@deriving
  show,
  protocol ~driver:(module Protocol.Toml),
  protocol ~driver:(module Protocol.Jinja2)]


(** Lib site specification. *)
type sites_spec = {
  sites_spec_exec : bool;                 [@default false][@key "exec"]
  sites_spec_root : bool;                 [@default false][@key "root"]
  sites_spec_dir : string;                [@default ""][@key "dir"]
  sites_spec_install : install_spec list; [@default []][@key "install"]
}
[@@deriving
  show,
  protocol ~driver:(module Protocol.Toml),
  protocol ~driver:(module Protocol.Jinja2)]

(** Various default values for sites. *)

let default_sites_name = "sites"
let default_sites_lib = []
let default_sites_bin = []
let default_sites_sbin = []
let default_sites_toplevel = []
let default_sites_share = []
let default_sites_etc = []
let default_sites_stublibs = []
let default_sites_doc = []
let default_sites_man = []

(** Sites' specification. *)
type sites = {

  sites_name : string;
  [@default default_sites_name]
  [@key "name"]

  sites_lib : sites_spec list;
  [@default default_sites_lib]
  [@key "lib"]

  sites_bin : sites_spec list;
  [@default default_sites_bin]
  [@key "bin"]

  sites_sbin : sites_spec list;
  [@default default_sites_sbin]
  [@key "sbin"]

  sites_toplevel : sites_spec list;
  [@default default_sites_toplevel]
  [@key "toplevel"]

  sites_share : sites_spec list;
  [@default default_sites_share]
  [@key "share"]

  sites_etc : sites_spec list;
  [@default default_sites_etc]
  [@key "etc"]

  sites_stublibs : sites_spec list;
  [@default default_sites_stublibs]
  [@key "stublibs"]

  sites_doc : sites_spec list;
  [@default default_sites_doc]
  [@key "doc"]

  sites_man : sites_spec list;
  [@default default_sites_man]
  [@key "man"]
}
[@@deriving
  show,
  protocol ~driver:(module Protocol.Toml),
  protocol ~driver:(module Protocol.Jinja2)]


type package =
  { name : string;
    mutable dir : string;
    mutable project : project;
    mutable kind : kind;
    mutable p_skeleton : string option;
    mutable p_pack : string option;
    mutable p_version : string option;
    mutable p_authors : string list option;
    mutable p_synopsis : string option;
    mutable p_description : string option;
    mutable p_dependencies : (string * dependency) list;
    mutable p_tools : (string * dependency) list;
    mutable p_pack_modules : bool option;
    mutable p_gen_version : string option;
    mutable p_fields : string StringMap.t;
    mutable p_generators : StringSet.t option;
    mutable p_menhir : menhir option;
    mutable p_file : string option;
    mutable p_skip : string list option;
    mutable p_optional : bool option;
    mutable p_preprocess : string option;
    mutable p_sites : sites;
  }

and project =
  { package : package; (* main package *)
    (* The list of all packages, including the main package *)
    mutable packages : package list;
    mutable file : string option; (* name of the file *)
    mutable generators : StringSet.t; (* sub-packages *)
    mutable menhir_version : string option; (* from sub-packages *)
    (* common fields *)
    mutable skeleton : string option;
    project_drom_version : string ;
    project_share_repo : string option ;
    project_share_version : string option ;
    edition : string;
    min_edition : string;
    (* not that ocamlformat => ocaml.4.04.0 *)
    github_organization : string option;
    homepage : string option;
    license : string;
    copyright : string option;
    bug_reports : string option;
    dev_repo : string option;
    doc_gen : string option;
    doc_api : string option;
    skip : string list;
    (* publish options *)
    archive : string option;
    (* sphinx options *)
    sphinx_target : string option;
    (* odoc options *)
    odoc_target : string option;
    (* CI options *)
    ci_systems : string list;
    skip_dirs : string list;
    profiles : profile StringMap.t;
    profile : string option;
    (* default fields *)
    version : string;
    authors : string list;
    synopsis : string;
    description : string;
    share_dirs : string list;
    mutable dependencies : (string * dependency) list;
    mutable tools : (string * dependency) list;
    mutable fields : string StringMap.t;
    year : int;
    mutable dune_version : string;
    mutable project_create : bool ;
  }

and profile = { flags : string StringMap.t }

type config =
  { config_author : string option;
    config_share_repo : string option;
    config_github_organization : string option;
    config_license : string option;
    config_copyright : string option;
    config_opam_repo : string option;
    config_dev_tools : string list option;
    config_auto_upgrade : bool option;
    config_auto_opam_yes : bool option;
    config_git_stage : bool option;
  }

type opam_kind =
  | Single
  | LibraryPart
  | ProgramPart
  | Deps

type switch_arg =
  | Local
  | Global of string

(* These flags are used during file generation. They can either be set
   in the file itself, or in the 'flags' section of the skeleton. *)
type flags =
  { mutable flag_file : string option;
    mutable flag_create : bool option;
    mutable flag_record : bool option;
    mutable flag_skips : string list;
    mutable flag_skip : bool option;
    mutable flag_subst : bool option;
    mutable flag_perm : int option;
    flag_skipper : bool list ref
  }

type skeleton =
  { skeleton_inherits : string option;
    skeleton_toml : string list; (* content of drom.toml or package.toml file *)
    skeleton_files : (string * string * int) list;
    skeleton_flags : flags StringMap.t;
    skeleton_drom : bool;
    skeleton_name : string;
    skeleton_version : string;
  }

type license =
  { license_key : string;
    license_name : string;
    license_header : string list;
    license_contents : string
  }

(* The content of the share-repo. Options are loaded on demand *)
type share = {
  share_dir : string ;
  share_version : string ;
  drom_version : string ;
  mutable share_licenses : license StringMap.t option ;
  mutable share_projects : skeleton StringMap.t option ;
  mutable share_packages : skeleton StringMap.t option ;
}

type deps_status =
  | Deps_build
  | Deps_devel
