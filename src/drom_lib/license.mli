(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open EzCompat

val licenses : Types.share -> Types.license StringMap.t

val name : Types.share -> Types.project -> string (* Short name of license *)

val header : Types.share -> ?sep:string * char * string -> Types.project -> string
val header_mll : Types.share -> Types.project -> string
val header_mly : Types.share -> Types.project -> string
val header_ml : Types.share -> Types.project -> string
val header_c : Types.share -> Types.project -> string

(* license text *)
val license : Types.share -> Types.project -> string

(* list of known licenses *)
val known_licenses : Types.share -> string
