(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

type hash

val digest_content : ?perm:int -> file:string -> content:string -> unit -> hash
val digest_file : string -> hash
val to_string : hash -> string
val perm_equal : int -> int -> bool

val old_string_hash : string -> hash

type t

(* load .drom file *)
val load : unit -> t

val remove : t -> string -> unit
val get : t -> string -> hash list
val write : t -> record:bool -> perm:int -> file:string -> content:string -> unit
val rename : t -> src:string -> dst:string -> unit
val with_ctxt : ?git:bool -> (t -> 'a) -> 'a
val update : ?git:bool -> t -> string -> hash list -> unit

(* read file either from Hashes of from disk *)
val read : t -> file:string -> string

val set_version : t -> string -> unit
