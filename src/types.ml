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

exception Error of string

type kind =
  | Program
  | Library

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

type dependency = {
  depversions : version list ;
  depname : string option ; (* for dune if different *)
}

type package = {
  name : string ;
  mutable dir : string ;
  mutable project : project ;
  mutable p_pack : string option ;
  mutable kind : kind ;
  p_version : string option ;
  p_authors : string list option ;
  p_synopsis : string option ;
  p_description : string option ;
  mutable p_dependencies : ( string * dependency ) list ;
  p_tools : ( string * dependency ) list ;
  p_mode : mode option ;
  p_pack_modules : bool option;
  mutable p_gen_version : string option ;
  mutable p_driver_only : string option ;
}

and project = {
  package : package ;
  packages : package list ; (* sub-packages *)

  (* common fields *)
  edition : string ;
  min_edition : string ;
  github_organization : string option ;
  homepage : string option ;
  license : string ;
  copyright : string option ;
  bug_reports : string option ;
  dev_repo : string option ;
  doc_gen : string option ;
  doc_api : string option ;
  skip : string list ;

  (* publish options *)
  archive : string option ;

  (* sphinx options *)
  sphinx_target : string option ;

  (* CI options *)
  windows_ci : bool ;

  skip_dirs : string list ;
  profiles : profile StringMap.t ;

  (* default fields *)
  version : string ;
  authors : string list ;
  synopsis : string ;
  description : string ;
  dependencies : ( string * dependency ) list;
  tools : ( string * dependency ) list;
  mode : mode ;
  pack_modules : bool ;
}

and profile = {
  flags : string StringMap.t ;
}

type config = {
  config_author : string option ;
  config_github_organization : string option ;
  config_license : string option ;
  config_copyright : string option ;
  config_opam_repo : string option ;
}

type opam_kind =
  | Single
  | LibraryPart
  | ProgramPart
  | Deps

type switch_arg =
  | Local
  | Global of string
