(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Ezcmd.V2

type update_args =
  { mutable arg_upgrade : bool;
    mutable arg_force : bool;
    mutable arg_diff : bool;
    mutable arg_skip : (bool * string) list;
    mutable arg_promote_skip : bool ;
  }

val update_args :
  unit ->
  update_args * (string list * EZCMD.TYPES.Arg.spec * EZCMD.TYPES.info) list

val update_files :
  twice:bool ->
  ?args:update_args ->
  ?git:bool ->
  ?create:bool ->
  Types.project ->
  unit

val compute_config_hash : (string * string) list -> string
