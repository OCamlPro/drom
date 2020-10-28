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

type mode =
  | Binary
  | Javascript

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
  { depversions : version list;
    (* "version" *)
    depname : string option;
    (* for dune if different *)
    (* "libname" *)
    deptest : bool;
    (* "for-test" *)
    depdoc : bool (* "for-doc" *)
  }

type package =
  { name : string;
    mutable dir : string;
    mutable project : project;
    mutable kind : kind;
    mutable p_skeleton : string option;
    mutable p_pack : string option;
    p_version : string option;
    p_authors : string list option;
    p_synopsis : string option;
    p_description : string option;
    mutable p_dependencies : (string * dependency) list;
    p_tools : (string * dependency) list;
    mutable p_mode : mode option;
    p_pack_modules : bool option;
    mutable p_gen_version : string option;
    mutable p_fields : string StringMap.t;
    mutable p_generators : string list option;

    mutable p_file : string option ;
  }

and project =
  { package : package;
    mutable packages : package list;
    mutable file : string option ; (* name of the file *)
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
    (* CI options *)
    windows_ci : bool;
    generators : string list;
    skip_dirs : string list;
    profiles : profile StringMap.t;
    profile : string option;
    (* default fields *)
    version : string;
    authors : string list;
    synopsis : string;
    description : string;
    dependencies : (string * dependency) list;
    tools : (string * dependency) list;
    mode : mode;
    pack_modules : bool;
    mutable fields : string StringMap.t
  }

and profile = { flags : string StringMap.t }

type config =
  { config_author : string option;
    config_github_organization : string option;
    config_license : string option;
    config_copyright : string option;
    config_opam_repo : string option
  }

type opam_kind =
  | Single
  | LibraryPart
  | ProgramPart
  | Deps

type switch_arg =
  | Local
  | Global of string

type skeleton =
  { skeleton_inherits : string option;
    skeleton_toml : string list;
    skeleton_files : (string * string) list
  }

module type LICENSE = sig
  val key : string

  val name : string

  val header : string list

  val license : string
end
