(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Ezcmd.TYPES

let cmd_name = "doc"

let action ~args ~open_www () =
  let (_p : Types.project) = Build.build ~dev_deps:true ~args () in
  Misc.call [| "opam"; "exec"; "--"; "dune"; "build"; "@doc" |];
  Misc.call
    [| "rsync"; "-auv"; "--delete"; "_build/default/_doc/_html/."; "docs/doc" |];
  if !open_www then
    Misc.call [| "xdg-open"; "_build/default/_doc/_html/index.html" |]

let cmd =
  let args, specs = Build.build_args () in
  let open_www = ref false in
  { cmd_name;
    cmd_action = (fun () -> action ~args ~open_www ());
    cmd_args =
      [ ( [ "view" ],
          Arg.Set open_www,
          Ezcmd.info "Open a browser on the documentation" )
      ]
      @ specs;
    cmd_man = [];
    cmd_doc = "Generate API documentation using odoc in the docs/doc directory"
  }
