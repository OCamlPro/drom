(* Configuration_Map -- Generic configuration facility

   Author: Michael Grünewald
   Date: Wed Oct 24 07:48:50 CEST 2012

   Copyright © 2012–2015 Michael Grünewald

   This file must be used under the terms of the CeCILL-B.
   This source file is licensed as described in the file COPYING, which
   you should have received as part of this distribution. The terms
   are also available at
   http://www.cecill.info/licences/Licence_CeCILL-B_V1-en.txt *)

(** Configuration maps.

    A configuration map holds a dictionary mapping configuration keys to
    configuration values.  Values available in a configuration map can
    retrieved based on a {i key} or consumed by an {i editor}.
    Configuration maps can be combined together. *)

(** The abstract type of configuration maps. *)
type t


(** {6 Keys and value retrieval}

    Configuration values are retrieved by a user defined function of
    type [string -> 'a].  This function is expected to not have any
    side-effect.  It must reports errors using the [Invalid_argument]
    or [Failure] exceptions. This specification allows to use the
    various [*_of_string] function in the standard library to examine
    configuration values. *)

(** The type of configuration keys.  A configuration key can be used
    to retrieve a configuration value. *)
type 'a key = {
  of_string: string -> 'a;
  path: string list;
  name: string;
  default: 'a;
  description: string;
}

(** [key concrete path name default description] create a key
    out of its given parts. *)
val key : (string -> 'a) -> string list -> string -> 'a -> string -> 'a key

(** Get the value associated with an key.  If there is no associated
    value, then the default value from the key is returned.

    @raise Failure if the value cannot be formatted. *)
val get : t -> 'a key -> 'a

(** [value key text] get the value associated to [text] as if it
    were assigned to [key]. *)
val value : 'a key -> string -> 'a


(** {6 Functional edition of program parameters} *)

(** The abstract type of functional configuration editors,
    functionally editing a value of type ['b]. *)
type 'b editor

(** [editor key edit] create a functional configuration editor consuming
    keys described by [key] and functionally editing a value of type
    ['b] with [edit]. *)
val editor : 'a key -> ('a -> 'b -> 'b) -> 'b editor

(** [xmap get set editor] convert an editor functionally modifying a
    value of type ['b] in an editor functionally modifying a value of type
    ['a].  This can be used in conjunction with lenses to separately
    configure the different modules of an application. *)
val xmap : ('a -> 'b) -> ('b -> 'a -> 'a) -> 'b editor -> 'a editor

(** Explicitely edit the given value with the provided editor. *)
val apply : t -> 'b editor -> 'b -> 'b


(** {6 Operations on configuration maps} *)

(** The empty configuration map. *)
val empty : t

(** Add a configuration binding. *)
val add : (string list * string) -> string -> t -> t

(** [merge a b] a configuration map looking up values in [a] then
    in [b]. *)
val merge : t -> t -> t

(** [override a b] a configuration map whose keys are the same as
    [a] and the values are possibly overriden by those found in [b]. *)
val override : t -> t -> t

(** Read configuration values from a file. *)
val from_file : string -> t

(** Read configuration values from a string. *)
val from_string : string -> t

(** Read configuration values from an alist. *)
val from_alist : ((string list * string) * string) list -> t

(** Convert configuration values to an alist. *)
val to_alist : t -> ((string list * string) * string) list
