(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro                                             *)
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
  ('a, Types.project) Subst.state ->
  unit

val lookup_project : Types.share -> string -> Types.skeleton

val lookup_package : Types.share -> string -> Types.skeleton

val known_skeletons : Types.share -> string

val default_flags : string -> Types.flags

val subst_package_file : Types.flags -> string ->
  ('a,  Types.package) Subst.state -> string

val project_skeletons : Types.share -> Types.skeleton list

val package_skeletons : Types.share -> Types.skeleton list

val to_string : Types.skeleton -> string
