(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Ezcmd.V2
open Types

type build_args =
  { mutable arg_switch : switch_arg option;
    mutable arg_yes : bool;
    mutable arg_edition : string option;
    mutable arg_upgrade : bool;
    mutable arg_profile : string option
  }

val build_args :
  unit ->
  build_args * (string list * EZCMD.TYPES.Arg.spec * EZCMD.TYPES.info) list

val build :
  args:build_args ->
  ?setup_opam:bool ->
  ?build_deps:bool ->
  ?force_build_deps:bool ->
  ?dev_deps:bool ->
  ?force_dev_deps:bool ->
  ?build:bool ->
  ?extra_packages:string list ->
  unit ->
  Types.project
