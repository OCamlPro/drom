(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

val find : unit -> (Types.project * string) option
val get : unit -> Types.project * string
val read : string -> Types.project

val toml_of_project : Types.project -> string

val create_package :
  name:string -> dir:string -> kind:Types.kind -> Types.package

val find_author : Types.config -> string
