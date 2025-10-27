(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

val args : ?set_share:bool -> unit ->
           Types.update_args * Ezcmd.V2.EZCMD.TYPES.arg_list

val update_files :
  Types.share ->
  twice:bool ->
  ?warning:bool ->
  ?update_args:Types.update_args ->
  ?git:bool ->
  Types.project ->
  unit

val compute_config_hash : (string * string) list -> Hashes.hash

val display_create_warning : Types.project -> unit
