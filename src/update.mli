(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

val update_files :
  ?mode:Types.mode ->
  ?upgrade:bool ->
  ?git:bool ->
  ?create:bool ->
  ?promote_skip:bool ->
  Types.project ->
  unit

val library_name : Types.package -> string

val library_module : Types.package -> string
