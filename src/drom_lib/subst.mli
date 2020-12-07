(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Ez_subst(* .V1 *)

val package :
  'context ->
  ?bracket:('context * Types.package) EZ_SUBST.t ->
  ?skipper:bool list ref ->
  Types.package ->
  string ->
  string

val project :
  'context ->
  ?bracket:('context * Types.project) EZ_SUBST.t ->
  ?skipper:bool list ref ->
  Types.project ->
  string ->
  string

val package_paren : 'a * Types.package -> string -> string
