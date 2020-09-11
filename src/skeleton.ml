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

let default =
  {
    project_files =
      Test.project_files @ Github.project_files @ Ocamlformat.project_files
      @ Ocpindent.project_files @ Sphinx.project_files @ Docs.project_files
      @ License.project_files @ Git.project_files @ Makefile.project_files;
    package_files =
      Dune.package_files @
      [] (* main.ml, index.mld and dune are hardcoded *);
  }

let write_files write_file p skeleton =
  let skeleton_dir = Globals.drom_dir // "skeleton" in

  let skeleton_project_dir = skeleton_dir // "project" in
  List.iter
    (fun (file, content) ->
      let drom_file = skeleton_project_dir // file in
      EzFile.make_dir ~p:true (Filename.dirname drom_file);
      EzFile.write_file drom_file content;

      let file = ref (Subst.project p file) in
      let create = ref false in
      let record = ref true in
      let skips = ref [] in
      let escape enc v =
        match enc with
        | "file" ->
            file := v;
            true (* set the filename in the content *)
        | "create" ->
            create := true;
            true (* create only once, no update *)
        | "skip" ->
            skips := v :: !skips;
            true (* skip if this flag is skipped *)
        | "no-record" ->
            record := false;
            true (* do not record file, always regen *)
        | _ -> false
      in
      let content = Subst.project ~escape p content in
      let file = !file in
      let create = !create in
      let skips = !skips in
      let record = !record in
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
          let file = package.dir // file in
          let file = ref (Subst.project p file) in
          let create = ref false in
          let record = ref true in
          let skips = ref [] in
          let escape enc v =
            match enc with
            | "file" ->
                file := v;
                true (* set the filename in the content *)
            | "create" ->
                create := true;
                true (* create only once, no update *)
            | "skip" ->
                skips := v :: !skips;
                true (* skip if this flag is skipped *)
            | "no-record" ->
                record := false;
                true (* do not record file, always regen *)
            | _ -> false
          in
          let content = Subst.package ~escape package content in
          let file = !file in
          let create = !create in
          let skips = !skips in
          let record = !record in
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
