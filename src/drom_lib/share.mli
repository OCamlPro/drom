(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)


type args = {
  mutable arg_reclone : bool ;
  mutable arg_no_fetch : bool ;
  mutable arg_version : string option ;
  mutable arg_repo : string option ;
}

(* Use `~set:true` if you want to be able to set `--share-version` and
   `--share-repo`, otherwise only `--reclone-share` and
   `--no-fetch-share` are provided. *)

val args : ?set:bool -> unit -> args * Ezcmd.V2.EZCMD.TYPES.arg_list

val load :
  ?args:args ->
  ?p:Types.project -> unit ->
  Types.share

val share_repo_default : unit -> string
