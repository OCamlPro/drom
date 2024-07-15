(**************************************************************************)
(*                                                                        *)
(*    Copyright 2024 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

(** This module implement various drivers for [ppx_protocol_conv]. *)


(** The ToML driver.

    We use [otoml] and not [toml]/[drom_toml]/[eztoml] because the
    latters use a silly array encoding (and not conform to the ToML standard)
    that prevents us to inject OCaml values into it without dynamic typing. *)
module Toml : Protocol_conv.Runtime.Driver
  with type t = Otoml.t

(** The Jinja2 driver.

    Jinja2 is the templating de facto standard for content templating. This
    drivers allows to use OCaml values (and specially records) as
    substitutions.

    We use the [jingoo] library which isn't complete according to Jinja2
    specification but quite sufficient for our current needs. *)
module Jinja2 : Protocol_conv.Runtime.Driver
  with type t = Jingoo.Jg_types.tvalue