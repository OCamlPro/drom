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
open EzFile.OP

let cmd_name = "odoc"

let make_odoc p =
  Misc.call [| "opam"; "exec"; "--"; "dune"; "build"; "@doc" |];
  let dir = Misc.odoc_target p in
  let odoc_target = Format.sprintf "_drom/docs/%s" dir in
  EzFile.make_dir ~p:true odoc_target;
  Misc.call
    [| "rsync"; "-auv"; "--delete"; "_build/default/_doc/_html/."; odoc_target |];
  odoc_target

let action ~args ~open_www () =
  let (p : Types.project) = Build.build ~dev_deps:true ~args () in
  let odoc_target = make_odoc p in
  if !open_www then
    Misc.call [| "xdg-open"; odoc_target // "index.html" |]

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
    cmd_doc = "Generate API documentation using odoc in the _drom/docs/doc directory"
  }
