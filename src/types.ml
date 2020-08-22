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

type project = {
  name : string ;
  version : string ;
  edition : string ;
  authors : string list ;
  kind : kind ;
  synopsis : string ;
  description : string ;
  github_organization : string option ;
  homepage : string option ;
  license : string option ;
  copyright : string option ;
  bug_reports : string option ;
  dev_repo : string option ;
  documentation : string option ;
  dependencies : ( string * string ) list;
  tools : ( string * string ) list;
  ignore : string list ;
}

type config = {
  config_author : string option ;
  config_github_organization : string option ;
  config_license : string option ;
  config_copyright : string option ;
}

let error fmt =
  Printf.kprintf (fun s -> raise (Error s) ) fmt
