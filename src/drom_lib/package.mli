(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

(*
val lookup : unit -> ( string * string ) option
val find : ?display:bool -> unit -> (Types.project * string) option
val get : unit -> Types.project * string

val read : ?default:Types.project -> string -> Types.project

val to_files : Types.project -> (string * string) list

val of_string : msg:string -> ?default:Types.project -> string -> Types.project

val find_author : Types.config -> string


val dummy_project : Types.project
*)

val dependencies_encoding :
  (string * Types.dependency) list EzToml.TYPES.encoding

val fields_encoding : string EzCompat.StringMap.t EzToml.TYPES.encoding

val skip_encoding : string list EzToml.TYPES.encoding

val versions_of_string : string -> Types.version list

val string_of_versions : Types.version list -> string

val create : name:string -> dir:string -> kind:Types.kind -> Types.package

val of_string : msg:string -> ?default:Types.project -> string -> Types.package

val to_string : Types.package -> string

val of_toml :
  ?default:Types.project -> Toml.Types.value Toml.Types.Table.t -> Types.package

val find : ?default:Types.project -> string -> Types.package
