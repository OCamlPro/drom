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

val read : ?default:Types.project -> string -> Types.project

val to_files : Types.project -> ( string * string ) list

val of_string : msg:string -> ?default:Types.project -> string -> Types.project

val create_package :
  name:string -> dir:string -> kind:Types.kind -> Types.package

val find_author : Types.config -> string

val package_of_string : msg:string -> string -> Types.package

val string_of_package : Types.package -> string

val dummy_project : Types.project
