(**************************************************************************)
(*                                                                        *)
(*  Copyright (c) 2020 OCamlPro & Origin Labs                             *)
(*                                                                        *)
(*  All rights reserved.                                                  *)
(*  This file is distributed under the terms of the GNU Lesser General    *)
(*  Public License version 2.1, with the special exception on linking     *)
(*  described in the LICENSE.md file in the root directory.               *)
(*                                                                        *)
(**************************************************************************)

(** Easy Substitutions in Strings

  [ez_subst] provides simple functions to perform substitutions
  of expressions in strings. By default, expressions are recognized as
  [${expr}] ([brace] substitution), [$(expr)] ([paren] substitution),
  [$[expr]] ([bracket] substitution) and [$var] ([var] substitution),
  but it can be further customized by:
  {ul
  {- changing the separator [sep] (default is ['$'])}
  {- using a symmetric notation [sym] (default is [false], whereas [true]
     means ['${ident}$'].)}
  }
  Escaping is done using '\\', i.e. any character preceeded by a
  backslash is printed as itself, and not interpreted as a beginning
  or ending separator for expression. Escaping can be controled using
  the [escape] argument, a reference that can be turned to [true] or
  [false] even during the substitution.
*)

type 'context t = ('context -> string -> string)
(** The type for functions performing the translation from [ident] to
    its replacement. ['context] is some information, that is from the
    initial call to the substitution. *)

exception UnclosedExpression of string
(** The only exception that may be raised by substitutions: it indicates
    that the end of the expression could not be found. *)

val string : ?sep:char -> ?sym:bool ->
  ?escape:bool ref ->
  ?brace:'context t ->
  ?paren:'context t ->
  ?bracket:'context t ->
  ?var:'context t ->
  'context -> string -> string
(** [string f context s] performs substitutions on [s] following [f],
   passing the context [context] to [f] for every expression,
   returning the result as a string. *)

val buffer : ?sep:char -> ?sym:bool ->
  ?escape:bool ref ->
  ?brace:'context t ->
  ?paren:'context t ->
  ?bracket:'context t ->
  ?var:'context t ->
  Buffer.t -> 'context -> string -> unit
(** [buffer f b context s] performs substitutions on [s] following [f],
   passing the context [context] to [f] for every expression,
   returning the result by appending it to the buffer [b]. *)
