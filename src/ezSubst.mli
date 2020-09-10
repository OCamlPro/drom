(**************************************************************************)
(*                                                                        *)
(*  Copyright (c) 2020 OCamlPro SAS & Origin Labs SAS                     *)
(*                                                                        *)
(*  All rights reserved.                                                  *)
(*  This file is distributed under the terms of the GNU Lesser General    *)
(*  Public License version 2.1, with the special exception on linking     *)
(*  described in the LICENSE.md file in the root directory.               *)
(*                                                                        *)
(**************************************************************************)

(* Perform substitutions in a string.
   * the separator is $ by default
   * $$ is transformed into $
   * ${[^}]} is substituted by calling [f "\1"]
   No other transformation takes place
 *)

val string : ?sep:char -> f:(string -> string) -> string -> string

val buffer : ?sep:char -> Buffer.t -> f:(string -> string) -> string -> unit
