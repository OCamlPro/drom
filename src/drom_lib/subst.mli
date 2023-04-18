(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Ez_subst (* .V1 *)

exception Postpone

type ('context, 'p) state = {
  context : 'context;
  p : 'p;
  share : Types.share ;
  postpone : bool ; (* can some operations be postponed (raise Postpone) *)
  hashes : Hashes.t option;
}

val state :
  ?postpone:bool ->
  ?hashes:Hashes.t ->
  'context ->
  Types.share ->
  'p ->
  ('context, 'p) state



type ('project, 'context) subst =
  ?bracket:('context, 'project) state EZ_SUBST.t ->
  ?skipper:bool list ref ->
  ('context, 'project) state ->
  string ->
  string

val package : ( Types.package, 'context ) subst

val project : ( Types.project, 'context ) subst

val package_paren : ('a, Types.package) state -> string -> string
