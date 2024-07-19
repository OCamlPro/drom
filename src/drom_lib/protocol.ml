(**************************************************************************)
(*                                                                        *)
(*    Copyright 2024 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

module Toml = struct

  module Driver : Ppx_protocol_driver.Driver with type t = Otoml.t = struct
    type t = Otoml.t

    let to_string_hum toml = Otoml.Printer.to_string toml

    let of_list = Otoml.array
    let to_list = function
      | Otoml.TomlArray a | Otoml.TomlTableArray a -> a
      | _ -> failwith "array expected"

    let is_list = function
      | Otoml.TomlArray _ | Otoml.TomlTableArray _ -> true | _ -> false

    let of_alist = Otoml.table
    let to_alist = function
      | Otoml.TomlTable l | Otoml.TomlInlineTable l -> l
      | _ -> failwith "table expected"


    let is_alist = function
      | Otoml.TomlTable _ | Otoml.TomlInlineTable _ -> true
      | _ -> false

    let of_int = Otoml.integer
    let to_int = function
      | Otoml.TomlInteger i -> i
      | _ -> failwith "int expected"

    let of_int32 i = Int32.to_int i |> of_int
    let to_int32 toml = to_int toml |> Int32.of_int

    let of_int64 i = Int64.to_int i |> of_int
    let to_int64 toml = to_int toml |> Int64.of_int

    let of_nativeint i = of_int (Nativeint.to_int i)
    let to_nativeint toml = to_int toml |> Nativeint.of_int

    let of_float = Otoml.float
    let to_float = function
      | Otoml.TomlFloat f -> f
      | _ -> failwith "float expected"

    let of_string = Otoml.string
    let to_string = function
      | Otoml.TomlString s -> s
      | _ -> failwith "string expected"

    let is_string = function
      | Otoml.TomlString _ -> true
      | _ -> false

      let of_char c = Otoml.string (String.make 1 c)
    let to_char = function
      | Otoml.TomlString s when String.length s > 0 ->
        String.get s 0 (* can't fail *)
      | _ -> failwith "char expected"


    let of_bool = Otoml.boolean
    let to_bool = function
      | Otoml.TomlBoolean b -> b
      | _ -> failwith "bool expected"

    let to_bytes toml = Bytes.of_string (to_string toml)
    let of_bytes bytes = of_string (Bytes.to_string bytes)

    (* ToML has no null value but they are used to encode/decode [None]
       with empty tables. *)
    let null = Otoml.table []
    let is_null = (=) null

  end

  module Make(P : Ppx_protocol_driver.Parameters) = struct
    include Ppx_protocol_driver.Make(Driver)(P)
  end
  include Make(Ppx_protocol_driver.Default_parameters)
end

module Jinja2 = struct

  module Driver : Ppx_protocol_driver.Driver
    with type t = Jingoo.Jg_types.tvalue =
  struct
    type t = Jingoo.Jg_types.tvalue

    let null = Jingoo.Jg_types.Tnull

    let is_null = (=) null

    let of_string = Jingoo.Jg_types.box_string
    let to_string jg =
      try Jingoo.Jg_types.unbox_string jg with _ -> failwith "string expected"

    let is_string = function
      | Jingoo.Jg_types.Tstr _ -> true
      | _ -> false

    let of_bytes b = of_string (Bytes.to_string b)
    let to_bytes jg = Bytes.of_string (to_string jg)

    let of_bool = Jingoo.Jg_types.box_bool
    let to_bool jg =
      try Jingoo.Jg_types.unbox_bool jg with _ -> failwith "bool expected"

    let of_float = Jingoo.Jg_types.box_float
    let to_float jg =
      try Jingoo.Jg_types.unbox_float jg with _ -> failwith "float expected"

    let of_int = Jingoo.Jg_types.box_int
    let to_int jg =
      try Jingoo.Jg_types.unbox_int jg with _ -> failwith "int expected"

    let of_int32 i = i |> Int32.to_int |> of_int
    let to_int32 jg = to_int jg |> Int32.of_int

    let of_int64 i = i |> Int64.to_int |> of_int
    let to_int64 jg = to_int jg |> Int64.of_int

    let of_nativeint i = i |> Nativeint.to_int |> of_int
    let to_nativeint jg = to_int jg |> Nativeint.of_int

    let of_char c = of_string (String.make 1 c)
    let to_char = function
      | Jingoo.Jg_types.Tstr s when String.length s > 0 ->
        String.get s 0 (* can't fail *)
      | _ -> failwith "char expected"

    let of_alist = Jingoo.Jg_types.box_obj
    let to_alist jg =
      try Jingoo.Jg_types.unbox_obj jg with _ -> failwith "alist expected"

    let is_alist = function
      | Jingoo.Jg_types.Tobj _ -> true
      | _ -> false

    let of_list = Jingoo.Jg_types.box_list
    let to_list jg =
      try Jingoo.Jg_types.unbox_list jg with _ -> failwith "list expected"

    let is_list = function
      | Jingoo.Jg_types.Tlist _ -> true
      | _ -> false

    (* Not very sure about this printing but it seems ok for our needs. *)
    let rec pp : t Fmt.t = fun ppf t ->
      match t with
      | Jingoo.Jg_types.Tnull -> Fmt.string ppf "null"
      | Jingoo.Jg_types.Tbool b -> Fmt.bool ppf b
      | Jingoo.Jg_types.Tint i -> Fmt.int ppf i
      | Jingoo.Jg_types.Tfloat f -> Fmt.float ppf f
      | Jingoo.Jg_types.Tstr s -> Fmt.(quote string) ppf s
      | Jingoo.Jg_types.Tlist l ->
        Fmt.(brackets (list ~sep:(any ";@ ") pp)) ppf l
      | Jingoo.Jg_types.Tset s ->
        Fmt.(braces (list ~sep:(any ";@ ") pp)) ppf s
      | Jingoo.Jg_types.Tobj o ->
        Fmt.(braces
          (list ~sep:(any ";@\n") (pair ~sep:(any " =@;") string pp))) ppf o
      | Jingoo.Jg_types.Thash h ->
        Fmt.(braces
          (hashtbl ~sep:(any ";@\n")
            (pair ~sep:(any " =@;") (brackets string) pp))) ppf h
      | Jingoo.Jg_types.Tpat _ ->
        Fmt.string ppf "<pattern>"
      | Jingoo.Jg_types.Tfun _ ->
        Fmt.string ppf "<function>"
      | Jingoo.Jg_types.Tarray a ->
        Fmt.(brackets (array ~sep:(any ",@ ") pp)) ppf a
      | Jingoo.Jg_types.Tlazy l ->
        pp ppf (Lazy.force l)
      | Jingoo.Jg_types.Tvolatile _ ->
        Fmt.string ppf "<volatile>"
      | Jingoo.Jg_types.Tsafe s ->
        Fmt.(quote string) ppf s

    let to_string_hum = Fmt.str "%a" pp


  end

  module Make(P : Ppx_protocol_driver.Parameters) = struct
    include Ppx_protocol_driver.Make(Driver)(P)
  end

  (* Overriding the default driver because we want explicit substitutions
     even with default values. *)
  module Defaults = struct
    include Ppx_protocol_driver.Default_parameters
    let omit_default_values = false
  end

  include Make(Defaults)

end