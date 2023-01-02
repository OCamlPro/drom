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
  perm:int ->
  unit ) ->
  Types.project ->
  unit

val lookup_project : string -> Types.skeleton

val lookup_package : string -> Types.skeleton

val known_skeletons : unit -> string

val default_flags : string -> Types.flags

val subst_package_file : Types.flags -> string -> Types.package -> string

val project_skeletons : unit -> Types.skeleton list

val package_skeletons : unit -> Types.skeleton list

val to_string : Types.skeleton -> string
