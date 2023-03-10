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

(* TODO: add licenses *)
let all_kinds = [ "projects"; "packages" ]

let cmd =
  let kinds = ref [] in
  let args, specs = Share.args ~set:true () in
  EZCMD.sub cmd_name
    (fun () ->
       let kinds =
         match !kinds with
         | []
         | [ "all" ] ->
             all_kinds
         | kinds -> kinds
       in
       List.iter
         (function
           | "projects" ->
               let share = Share.load ~args () in
               Printf.printf "Known project skeletons: %s\n%!"
                 (String.concat " "
                    (List.map
                       (fun s -> s.skeleton_name)
                       (Skeleton.project_skeletons share) ) )
           | "packages" ->
               let share = Share.load ~args () in
               Printf.printf "Known packages skeletons: %s\n%!"
                 (String.concat " "
                    (List.map
                       (fun s -> s.skeleton_name)
                       (Skeleton.package_skeletons share) ) )
           | s ->
               Printf.eprintf "Error: unknown kind: %S. Possible kinds: %s\n%!" s
                 (String.concat " " all_kinds);
               exit 2 )
         kinds )
    ~args:
      ( specs @
        [ ( [],
            Arg.Anons (fun list -> kinds := list),
            EZCMD.info
              "Use 'projects' or 'packages' to display corresponding skeletons" )
        ])
    ~doc:"List available project or packages skeletons" ~version:"0.4.0"
    ~man:
      [ `S "DESCRIPTION";
        `Blocks [ `P "List available project or packages skeletons" ]
      ]
