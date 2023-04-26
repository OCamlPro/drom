(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

val lookup : unit -> (string * string) option

val find : ?display:bool -> unit -> (Types.project * string) option

val get : unit -> Types.project * string

val of_file : ?default:Types.project -> string -> Types.project

val to_files : Types.share -> Types.project -> (string * string) list

val of_string : msg:string -> ?default:Types.project -> string -> Types.project

val find_author : Types.config -> string
