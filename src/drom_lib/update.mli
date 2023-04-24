(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

type args =
  { mutable arg_upgrade : bool;
    mutable arg_force : bool;
    mutable arg_diff : bool;
    mutable arg_skip : (bool * string) list;
    mutable arg_promote_skip : bool;
    mutable arg_edition : string option;
    mutable arg_min_edition : string option;
    mutable arg_create : bool option ;

    arg_share_version : string option;
    arg_share_repo : string option;
  }

val args : unit ->  args * Ezcmd.V2.EZCMD.TYPES.arg_list

val update_files :
  Types.share ->
  twice:bool ->
  ?warning:bool ->
  ?args:args ->
  ?git:bool ->
  Types.project ->
  unit

val compute_config_hash : (string * string) list -> Hashes.hash

val display_create_warning : Types.project -> unit
