(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
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
  { depversions : version list; (* "version" *)
    depname : string option;    (* "libname" *)
    (* for dune if different *)
    deptest : bool; (* "for-test" *)
    depdoc : bool (* "for-doc" *)
  }

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
    mutable p_file : string option
  }

and project =
  { package : package; (* main package *)
    (* The list of all packages, including the main package *)
    mutable packages : package list;
    mutable file : string option; (* name of the file *)
    mutable generators : StringSet.t;
    (* sub-packages *)

    (* common fields *)
    mutable skeleton : string option;
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
    share_dirs : string list ;
    mutable dependencies : (string * dependency) list;
    mutable tools : (string * dependency) list;
    mutable fields : string StringMap.t
  }

and profile = { flags : string StringMap.t }

type config =
  { config_author : string option;
    config_share_dir : string option;
    config_github_organization : string option;
    config_license : string option;
    config_copyright : string option;
    config_opam_repo : string option;
    config_dev_tools : string list;
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
  { mutable flag_file : string;
    mutable flag_create : bool;
    mutable flag_record : bool;
    mutable flag_skips : string list;
    mutable flag_skip : bool ;
    mutable flag_subst : bool ;
    flag_skipper : bool list ref ;
  }

type skeleton =
  { skeleton_inherits : string option;
    skeleton_toml : string list;
    skeleton_files : (string * string * int) list;
    skeleton_flags : flags StringMap.t;
    skeleton_drom : bool ;
    skeleton_name : string ;
  }

type license = {
  license_key : string ;
  license_name : string ;
  license_header : string list ;
  license_contents : string ;
}

type deps_status =
  | Deps_build
  | Deps_devel
  | Deps_locked
