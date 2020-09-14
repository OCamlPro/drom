(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Types
open EzFile.OP

type flags = {
  mutable file : string ;
  mutable create : bool ;
  mutable record : bool ;
  mutable skips : string list ;
}

let bracket file =
  let flags = {
    file ;
    create = false ;
    record = true ;
    skips = []
  } in
  let bracket flags _ s =
    match EzString.split s ':' with
    (* set the name of the file *)
    | [ "file" ;  v ] -> flags.file <- v; ""

    (* create only once *)
    | [ "create" ] -> flags.create <- true; ""

    (* skip with this tag *)
    | [ "skip" ; v ] -> flags.skips <- v :: flags.skips; ""

    (* do not record in .git *)
    | [ "no-record" ] -> flags.record <- false; ""
    | _ -> ""
  in
  ( flags , bracket flags )

let write_files write_file p skeleton =
  let skeleton_dir = Globals.drom_dir // "skeleton" in

  let skeleton_project_dir = skeleton_dir // "project" in
  List.iter
    (fun (file, content) ->
       let drom_file = skeleton_project_dir // file in
       EzFile.make_dir ~p:true (Filename.dirname drom_file);
       EzFile.write_file drom_file content;

       let (flags, bracket) = bracket (Subst.project () p file) in
       let content =
         try Subst.project () ~bracket p content with
         | Not_found ->
             Printf.eprintf "Exception Not_found in %S\n%!" drom_file ;
             exit 2
       in
       let { file ; create ; skips ; record } = flags in
       write_file file ~create ~skips ~content ~record)
    skeleton.project_files;

  let skeleton_package_dir = skeleton_dir // "package" in
  List.iter
    (fun (file, content) ->
       let drom_file = skeleton_package_dir // file in
       EzFile.make_dir ~p:true (Filename.dirname drom_file);
       EzFile.write_file drom_file content)
    skeleton.package_files;

  List.iter
    (fun package ->
       List.iter
         (fun (file, content) ->
            let drom_file = package.dir // file in
            let (flags, bracket) =
              bracket (Subst.package () package drom_file) in
            let content = try
                Subst.package () ~bracket package content
              with Not_found ->
                Printf.eprintf "Exception Not_found in %S\n%!" drom_file ;
                exit 2
            in
            let { file ; create ; skips ; record } = flags in
            write_file file ~create ~skips ~content ~record)
         skeleton.package_files)
    p.packages

let load name =
  let skeleton_dir = Globals.config_dir // "skeletons" // name in
  if not (Sys.file_exists skeleton_dir) then (
    Printf.eprintf
      "Warning: skeleton %s/ not found. Skipping skeleton files.\n%!"
      skeleton_dir;
    None )
  else
    let rec iter todo ret =
      match todo with
      | [] -> ret
      | (dir, dirname) :: todo -> (
          match Unix.stat dir with
          | exception _exn ->
              (* warning ? *)
              iter todo ret
          | st -> (
              match st.Unix.st_kind with
              | S_REG ->
                  let content = EzFile.read_file dir in
                  iter todo ((dirname, content) :: ret)
              | S_DIR ->
                  let files = Sys.readdir dir in
                  let files =
                    Array.map (fun file -> (dir // file, dirname // file)) files
                  in
                  let files = Array.to_list files in
                  iter (todo @ files) ret
              | _ ->
                  (* warning *)
                  iter todo ret ) )
    in
    Some
      {
        project_files = iter [ (skeleton_dir // "project", "") ] [];
        package_files = iter [ (skeleton_dir // "package", "") ] [];
      }
