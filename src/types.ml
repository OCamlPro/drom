(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

exception Error of string

type kind =
  | Program
  | Library
  | Both

type mode =
  | Binary
  | Javascript

type dependency = {
  depversion : string ;
  depname : string option ; (* for dune if different *)
}

type package = {
  name : string ;
  dir : string ;
  mutable project : project ; (* mutable for late initialization *)
  p_pack : string option ;
  p_kind : kind option ;
  p_version : string option ;
  p_authors : string list option ;
  p_synopsis : string option ;
  p_description : string option ;
  p_dependencies : ( string * dependency ) list option ;
  p_tools : ( string * string ) list option ;
  p_mode : mode option ;
  p_wrapped : bool option;
}

and project = {
  package : package ;

  (* common fields *)
  edition : string ;
  min_edition : string ;
  kind : kind ;
  github_organization : string option ;
  homepage : string option ;
  license : string ;
  copyright : string option ;
  bug_reports : string option ;
  dev_repo : string option ;
  doc_gen : string option ;
  doc_api : string option ;
  skip : string list ;
  archive : string option ;

  (* default fields *)
  version : string ;
  authors : string list ;
  synopsis : string ;
  description : string ;
  dependencies : ( string * dependency ) list;
  tools : ( string * string ) list;
  mode : mode ;
  wrapped : bool ;
}

type config = {
  config_author : string option ;
  config_github_organization : string option ;
  config_license : string option ;
  config_copyright : string option ;
  config_opam_repo : string option ;
}
