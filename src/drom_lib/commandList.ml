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
open Types
open EZCMD.TYPES

let cmd_name = "list"

let all_kinds = [ "projects"; "packages" ]

let cmd =
  let args = ref [] in
  EZCMD.sub cmd_name
    (fun () ->
      let args =
        match !args with
        | []
        | [ "all" ] ->
          all_kinds
        | args -> args
      in
      List.iter
        (function
          | "projects" ->
            Printf.printf "Known project skeletons: %s\n%!"
              (String.concat " "
                 (List.map
                    (fun s -> s.skeleton_name)
                    (Skeleton.project_skeletons ()) ) )
          | "packages" ->
            Printf.printf "Known packages skeletons: %s\n%!"
              (String.concat " "
                 (List.map
                    (fun s -> s.skeleton_name)
                    (Skeleton.package_skeletons ()) ) )
          | s ->
            Printf.eprintf "Error: unknown kind: %S. Possible kinds: %s\n%!" s
              (String.concat " " all_kinds);
            exit 2 )
        args )
    ~args:
      [ ( [],
          Arg.Anons (fun list -> args := list),
          EZCMD.info
            "Use 'projects' or 'packages' to display corresponding skeletons" )
      ]
    ~doc:"List available project or packages skeletons" ~version:"0.4.0"
    ~man:
      [ `S "DESCRIPTION";
        `Blocks [ `P "List available project or packages skeletons" ]
      ]
