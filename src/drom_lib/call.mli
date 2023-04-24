(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

val call :
  ?exec:bool ->
  ?stdout:Unix.file_descr ->
  ?stderr:Unix.file_descr ->
  ?print_args:string list -> string list -> unit
val silent : ?print_args:string list -> string list -> unit

val call_get_fst_line : string -> string option

val wget : url:string -> output:string -> unit


val before_hook : ?args:string list -> command:string -> unit -> unit
val after_hook : ?args:string list -> command:string -> unit -> unit
