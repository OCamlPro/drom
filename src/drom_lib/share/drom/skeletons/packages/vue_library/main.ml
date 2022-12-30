(**************************************************************************)
(*                                                                        *)
(*  Copyright (c) 2020 Maxime Levillain <maxime.levillain@origin-labs.com>*)
(*                                                                        *)
(*  All rights reserved.                                                  *)
(*  This file is distributed under the terms of the GNU Lesser General    *)
(*  Public License version 2.1, with the special exception on linking     *)
(*  described in the LICENSE.md file in the root directory.               *)
(*                                                                        *)
(*                                                                        *)
(**************************************************************************)

(* If you delete or rename this file, you should add
   'src/vue-skeleton_lib/main.ml' to the 'skip' field in "drom.toml" *)

open Js_of_ocaml

include Vue_js.Make (struct
  type data = < version : Js.js_string Js.t Js.readonly_prop >

  type all = data

  let id = "app"
end)

let data =
  object%js
    val version = Js.string Version.version
  end

let components =
  [ ( "hello",
      Js.Unsafe.coerce (Vue_component.make ~template:Templates.hello "hello") )
  ]

let main () =
  let vue = init ~data () in
  ignore vue
