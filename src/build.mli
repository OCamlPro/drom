(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Types

type build_args =
  switch_arg option ref * bool ref * string option ref

val build_args : unit -> build_args *
  (string list * Ezcmd.TYPES.Arg.spec * Ezcmd.TYPES.info) list

val build :
  args:build_args ->
  ?setup_opam:bool ->
  ?dev_deps:bool ->
  ?force_build_deps:bool ->
  ?build_deps:bool -> ?build:bool -> unit -> Types.project
