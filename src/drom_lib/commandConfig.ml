(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open EzCompat
open Ezcmd.V2
open EZCMD.TYPES
open Types

let cmd_name = "config"

let sprintf_flag flag fmt =
  match flag with
  | None -> ""
  | Some x ->
      Printf.sprintf fmt x

let string_of_flags f =
  Printf.sprintf "{%s%s%s%s%s%s }"
    (sprintf_flag f.flag_file " file = %S;" )
    (sprintf_flag f.flag_create " create = %b;" )
    (sprintf_flag f.flag_record " record = %b;" )
    (sprintf_flag f.flag_skip " skip = %b;")
    (sprintf_flag f.flag_subst " subst = %b;")
    (match f.flag_skips with
     | [] -> ""
     | list ->
         Printf.sprintf " skips = [%s];" (String.concat " " list))

let string_of_skeleton s =
  match !Globals.verbosity with
  | 0 -> s.skeleton_name
  | 1 ->
    Printf.sprintf "%s (%s)" s.skeleton_name
      ( if s.skeleton_drom then
        "drom"
      else
        "user" )
  | _ ->
    Printf.sprintf {|{ skeleton_name = %S (%s);%s%s
}|} s.skeleton_name
      ( if s.skeleton_drom then
        "drom"
      else
        "user" )
      ( match s.skeleton_inherits with
      | None -> ""
      | Some super -> Printf.sprintf "\n  skeleton_inherits = %S;" super )
      ( match StringMap.to_list s.skeleton_flags with
      | [] -> ""
      | list ->
        Printf.sprintf "\n  skeleton_flags = [%s\n ];"
          (String.concat ""
             (List.map
                (fun (file, flags) ->
                  Printf.sprintf "\n    %s -> %s" file (string_of_flags flags)
                  )
                list ) ) )

type action =
  | PrintPackageSkeletons
  | PrintProjectSkeletons

let action ~args act =
  match act with
  | PrintPackageSkeletons ->
      let share = Share.load ~args () in
      Printf.printf "%s\n%!"
        ( Skeleton.package_skeletons share
          |> List.map string_of_skeleton
          |> String.concat "\n" )
  | PrintProjectSkeletons ->
      let share = Share.load ~args () in
      Printf.printf "%s\n%!"
        ( Skeleton.project_skeletons share
          |> List.map string_of_skeleton
          |> String.concat "\n" )

let cmd =
  let todo = ref None in
  let set_action name action =
    match !todo with
    | None -> todo := Some (name, action)
    | Some (old_name, _) ->
      Printf.eprintf
        "Error: you can not use both --%s and --%s in the same command\n%!" name
        old_name;
      exit 2
  in
  let args, specs = Share.args ~set:true () in
  EZCMD.sub cmd_name
    ~args:
    ( specs @
      [ ( [ "package-skeletons" ],
          Arg.Unit
            (fun () -> set_action "package-skeletons" PrintPackageSkeletons),
          EZCMD.info "List available package skeletons" );
        ( [ "project-skeletons" ],
          Arg.Unit
            (fun () -> set_action "project-skeletons" PrintProjectSkeletons),
          EZCMD.info "List available project skeletons" );
      ])
    ~doc:"Read/write configuration"
    (fun () ->
      match !todo with
      | None ->
        Printf.eprintf "You must specify an action to perform\n%!";
        exit 2
      | Some (_, todo) -> action ~args todo )
    ~man:
      [ `S "DESCRIPTION";
        `Blocks [ `P "This command is useful to read/write drom configuration" ];
        `S "EXAMPLE";
        `P "The following displays the list of project skeletons:";
        `Pre {|
drom config --project-skeletons
|}
      ]
