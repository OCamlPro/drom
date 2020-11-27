(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Ezcmd.V2
open EZCMD.TYPES

let cmd_name = "doc"

let action ~args ~open_www () =
  let (p : Types.project) = Build.build ~dev_deps:true ~args () in
  let (_odoc_target : string ) = CommandOdoc.make_odoc p in
  let (_sphinx_target : string ) = CommandSphinx.make_sphinx p in
  if !open_www then
    Misc.call [| "xdg-open"; "_drom/docs/index.html" |]

let cmd =
  let args, specs = Build.build_args () in
  let open_www = ref false in
  EZCMD.sub cmd_name
    (fun () -> action ~args ~open_www ())
    ~args: (
      [ ( [ "view" ],
          Arg.Set open_www,
          EZCMD.info "Open a browser on the documentation" )
      ]
      @ specs
    )
    ~doc: "Generate all documentation (API and Sphinx)"
