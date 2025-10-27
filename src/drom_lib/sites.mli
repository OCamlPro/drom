(**************************************************************************)
(*                                                                        *)
(*    Copyright 2024 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

(** This module implement sites management. *)

(** Just aliasing {!Types.sites}. *)
type t = Types.sites
[@@deriving
  show,
  protocol ~driver:(module Protocol.Toml),
  protocol ~driver:(module Protocol.Jinja2)]

(** The default sites specification. *)
val default : t

(** Converts an eztoml value to a sites value. *)
val of_eztoml : EzToml.TYPES.value -> t

(** Generates the package dune stanza for sites. *)
val to_dune_project : t -> string

(** Generates the dynamic sites stanzas for [package]'s dune. *)
val to_dune : package:string -> t -> string