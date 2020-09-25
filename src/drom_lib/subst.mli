(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

val package :
  'context ->
  ?bracket:('context * Types.package) Ez_subst.t ->
  Types.package -> string -> string
val project :
  'context ->
  ?bracket:('context * Types.project) Ez_subst.t ->
  Types.project -> string -> string
