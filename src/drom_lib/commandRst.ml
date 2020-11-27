(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

(* This file should be moved to ez_cmdliner. However, it depends on ez_subst,
   that has not yet been published independantly. *)

open Ez_subst.V1
open EzCompat
open Ezcmd.V2
open EZCMD.TYPES
open EZCMD.RAWTYPES

let doclang_to_rst ?(map= StringMap.empty) s =
  let paren map s =
    match StringMap.find s map with
    | s -> s
    | exception Not_found ->
        match EzString.chop_prefix s ~prefix:"b," with
        | Some s -> Printf.sprintf "**%s**" s
        | None ->
            match EzString.chop_prefix s ~prefix:"i," with
            | Some s -> Printf.sprintf "*%s*" s
            | None ->
                s
  in
  EZ_SUBST.string ~paren:paren map s

let man_to_rst ?(map = StringMap.empty) ( man : block list ) =
  let b = Buffer.create 1000 in
  let rec iter = function
    | `S s ->
        let s = doclang_to_rst ~map s in
        Printf.bprintf b "\n\n**%s**\n\n" s
    | `Blocks list -> List.iter iter list
    | `I (label, txt) ->
        Printf.bprintf b "\n* %s\n  %s\n"
          ( doclang_to_rst ~map label )
          ( doclang_to_rst ~map txt )
    | `Noblank -> ()
    | `P par ->
        Printf.bprintf b "\n%s\n" ( doclang_to_rst ~map par )
    | `Pre code ->
        let code = doclang_to_rst ~map code in
        Printf.bprintf b "::\n  %s\n"
          ( String.concat "\n  "
              ( EzString.split code '\n' ))

  in
  List.iter iter man;
  Buffer.contents b


let action commands _common_args =

  let commands = List.map EZCMD.raw_sub commands in

  let commands = List.sort (fun cmd1 cmd2 ->
      compare cmd1.sub_name cmd2.sub_name) commands in
  let b = Buffer.create 10000 in

  Printf.bprintf b
    {|
Sub-commands and Arguments
==========================

For version: %s

Overview::
|} Version.version;

  List.iter (fun cmd ->
      Printf.bprintf b "  \n  %s%s\n    %s\n" cmd.sub_name
        (match cmd.sub_version with
         | None -> ""
         | Some version -> Printf.sprintf " (since version %s)" version)
        (doclang_to_rst cmd.sub_doc)
    ) commands;

  List.iter (fun cmd ->

      let s = Printf.sprintf "\n\ndrom %s%s" cmd.sub_name
          (match cmd.sub_version with
           | None -> ""
           | Some version -> Printf.sprintf " (since version %s)" version)
      in
      Printf.bprintf b "%s\n%s\n\n" s
        ( String.make ( String.length s) '~' );

      Printf.bprintf b "%s\n\n"
        (doclang_to_rst cmd.sub_doc);

      Printf.bprintf b "%s" (man_to_rst cmd.sub_man);

      let options = cmd.sub_args in
      (* TODO: compare may fail on arguments because they contain closures... *)
      let options = List.sort compare options in
      let options = List.map (fun (args, f, info) ->
          (args, f, EZCMD.raw_info info)) options in
      let arg_name info name =
        match info.arg_docv with
        | None -> name
        | Some name -> name
      in
      let arg_name f info =
        match f with
        | Arg.String _ -> arg_name info "STRING"
        | Arg.Bool _ -> arg_name info "BOOL"
        | Arg.Int _ -> arg_name info "INT"
        | Arg.Float _ -> arg_name info "FLOAT"
        | Arg.Set_string _ -> arg_name info "STRING"
        | Arg.Set_bool _ -> arg_name info "BOOL"
        | Arg.Set_int _ -> arg_name info "INT"
        | Arg.Set_float _ -> arg_name info "FLOAT"
        | Arg.Unit _
        | Arg.Set _
        | Arg.Clear _
          -> ""
        | Arg.File _ -> arg_name info "FILE"
        | Arg.Anon (_, _) -> arg_name info "ARGUMENT"
        | Arg.Anons _ -> arg_name info "ARGUMENTS"
        | Arg.Symbol (list, _) ->
            arg_name info (Printf.sprintf "[%s]"
                             ( String.concat "|" list))
      in


      Printf.bprintf b "\n**USAGE**\n::\n  \n  drom %s%s [OPTIONS]\n\n"
        cmd.sub_name
        ( String.concat ""
            ( List.map (function
                    ( [], f, info ) ->
                      " " ^ arg_name f info
                  | _ -> "") options))
      ;
      Printf.bprintf b "Where options are:\n\n";

      let print_options options =

        List.iter (fun (option, f, info)  ->
            let arg_name = arg_name f info in
            let map = StringMap.add "docv" arg_name StringMap.empty in
            Printf.bprintf b "\n* %s "
              (match option with
               | [] ->
                   Printf.sprintf ":code:`%s`" arg_name
               | _ ->
                   let arg_name = if arg_name = "" then "" else
                       " " ^ arg_name in
                   String.concat " or " @@
                   List.map (fun s ->
                       if String.length s = 1 then
                         Printf.sprintf ":code:`-%s%s`" s arg_name
                       else
                         Printf.sprintf ":code:`--%s%s`" s arg_name
                     ) option );
            Printf.bprintf b "  %s%s\n"
              (match info.arg_version with
               | None -> ""
               | Some version -> Printf.sprintf "(since version %s) " version)
              ( doclang_to_rst ~map info.arg_doc )

          ) options;
      in
      print_options options;

    ) commands;


  Printf.printf "%s%!" ( Buffer.contents b )
