(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

val write_files :
  (string ->
  create:bool ->
  skips:string list ->
  content:string ->
  record:bool ->
  skip:bool ->
  unit) ->
  Types.project ->
  unit

val lookup_project : string option -> Types.skeleton

val lookup_package : string -> Types.skeleton

val known_skeletons : unit -> string
