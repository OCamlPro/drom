(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open EzCompat
open Types
open EzFile.OP

type flags = {
  mutable file : string;
  mutable create : bool;
  mutable record : bool;
  mutable skips : string list;
  mutable skip : bool ;
}

let bracket file =
  let flags = { file; create = false; record = true; skips = [] ;
                skip = false ;} in
  let bracket flags _ s =
    match EzString.split s ':' with
    (* set the name of the file *)
    | [ "file"; v ] ->
        flags.file <- v;
        ""
    (* create only once *)
    | [ "create" ] ->
        flags.create <- true;
        ""
    (* skip with this tag *)
    | [ "skip"; v ] ->
        flags.skips <- v :: flags.skips;
        ""
    (* skip always *)
    | [ "skip" ] ->
        flags.skip <- true ;
        ""
    (* do not record in .git *)
    | [ "no-record" ] ->
        flags.record <- false;
        ""
    | _ ->
        Printf.eprintf "Warning: unknown flag %S\n%!" s;
        ""
  in
  (flags, bracket flags)

let load_skeleton ~dir ~toml ~kind =
    let table =
    match EzToml.from_file toml with
    | `Ok table -> table
    | `Error _ -> Error.raise "Could not parse skeleton file %S" toml
  in

  let name = EzToml.get_string table [ "skeleton"; "name" ] in
  let skeleton_inherits = EzToml.get_string_option table
      [ "skeleton"; "inherits" ] in
  let skeleton_toml =
    let file = dir // ( kind ^ ".toml" ) in
    if Sys.file_exists file then
      [ EzFile.read_file file ]
    else
      []
  in
  let skeleton_files =
    let dir = dir // "files" in
    let files = ref [] in
    EzFile.make_select EzFile.iter_dir ~deep:true dir ~kinds:[S_REG; S_LNK]
      ~f:(fun path ->
          let content = EzFile.read_file ( dir // path ) in
          files := ( path, content ) :: !files
        );
    !files
  in
  name, {
    skeleton_toml ;
    skeleton_inherits ;
    skeleton_files ;
  }

let load_skeletons map kind =
  let map = ref map in
  let skeletons_dir = Globals.config_dir // "skeletons" // kind in
  if Sys.file_exists skeletons_dir then
    EzFile.iter_dir skeletons_dir ~f:(fun file ->
        let dir = skeletons_dir // file in
        let toml = dir // "skeleton.toml" in
        if Sys.file_exists toml then
          let (name, skeleton ) = load_skeleton ~dir ~toml ~kind in
          map := StringMap.add name skeleton !map
      );
  !map

(*
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
*)

let builtin_project_skeletons = StringMap.of_list [
    "virtual", Skel_project_virtual.project_skeleton ;
    "program", Skel_project_program.project_skeleton ;
    "library", Skel_project_library.project_skeleton ;
  ]

let builtin_package_skeletons = StringMap.of_list [
    "virtual", Skel_package_virtual.package_skeleton ;
    "library", Skel_package_library.package_skeleton ;
    "program", Skel_package_program.package_skeleton ;
    "driver", Skel_package_driver.package_skeleton ;
  ]

let project_skeletons =
  lazy (
      load_skeletons builtin_project_skeletons "projects"
    )

let package_skeletons =
  lazy (
      load_skeletons builtin_package_skeletons "packages"
    )

let rec inherit_files self_files super_files =
  match self_files, super_files with
  | _, [] -> self_files
  | [], _ -> super_files
  | (self_file, self_content) :: self_files_tail ,
    (super_file, super_content) :: super_files_tail  ->
      if self_file = super_file then
        ( self_file, self_content ) ::
        inherit_files self_files_tail super_files_tail
      else
      if self_file < super_file then
        ( self_file, self_content ) ::
        inherit_files self_files_tail super_files
      else
        ( super_file, super_content ) ::
        inherit_files self_files super_files_tail

let lookup_skeleton skeletons name =
  let skeletons = Lazy.force skeletons in
  let rec iter name =
    match StringMap.find name skeletons with
    | exception Not_found ->
        Error.raise "Missing skeleton %S" name
    | self ->
        match self.skeleton_inherits with
        | None ->
            self
        | Some super ->
            let super = iter super in
            let skeleton_toml = self.skeleton_toml @ super.skeleton_toml in
            let skeleton_files =
              inherit_files self.skeleton_files super.skeleton_files
            in
            {
              skeleton_inherits = None ;
              skeleton_toml ;
              skeleton_files ;
            }
  in
  iter name

let backup_skeleton file content =
  let skeleton_dir = Globals.drom_dir // "skeleton" in
  let drom_file = skeleton_dir // file in
  EzFile.make_dir ~p:true (Filename.dirname drom_file);
  EzFile.write_file drom_file content

let lookup_project skeleton =
  lookup_skeleton project_skeletons
    (match skeleton with
     | None -> "program"
     | Some skeleton -> skeleton)

let lookup_package skeleton =
  lookup_skeleton package_skeletons skeleton

let write_project_files write_file p =

  let skeleton = lookup_project p.skeleton in
  List.iter
    (fun (file, content) ->
       backup_skeleton file content;

       let flags, bracket = bracket (Subst.project () p file) in
       let content =
         try Subst.project () ~bracket p content
         with Not_found ->
           Printf.eprintf "Exception Not_found in %S\n%!" file;
           exit 2
       in
       let { file; create; skips; record ; skip } = flags in
       write_file file ~create ~skips ~content ~record ~skip)
    skeleton.skeleton_files;
  ()

let write_package_files write_file package =

  let skeleton = lookup_package (match package.p_skeleton with
      | Some skeleton -> skeleton
      | None ->
          match package.kind with
          | Program -> "program"
          | Library -> "library"
          | Virtual -> "virtual")
  in

  List.iter
    (fun (file, content) ->
       let file = package.dir // file in
       backup_skeleton file content;
       let flags, bracket = bracket (Subst.package () package file) in
       let content =
         try Subst.package () ~bracket package content
         with Not_found ->
           Printf.eprintf "Exception Not_found in %S\n%!" file;
           exit 2
       in
       let { file; create; skips; record; skip } = flags in
       write_file file ~create ~skips ~content ~record ~skip)
    skeleton.skeleton_files

let write_files write_file p =
  write_project_files write_file p ;

  List.iter
    (fun package ->
       write_package_files write_file package
    )
    p.packages
