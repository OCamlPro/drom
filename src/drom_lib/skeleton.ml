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

let default_flags =
    { flag_file = "";
      flag_create = false;
      flag_record = true;
      flag_skips = [];
      flag_skip = false ;
      flag_skipper = ref [];
      flag_subst = true ;}

let bracket flags eval_cond =
  let bracket flags ( (), p ) s =
    match EzString.split s ':' with
    (* set the name of the file *)
    | [ "file"; v ] ->
      flags.flag_file <- v;
      ""
    (* create only once *)
    | [ "create" ] ->
      flags.flag_create <- true;
      ""
    (* skip with this tag *)
    | [ "skip"; v ] ->
      flags.flag_skips <- v :: flags.flag_skips;
      ""
    (* skip always *)
    | [ "skip" ] ->
      flags.flag_skip <- true;
      ""
    (* do not record in .git *)
    | [ "no-record" ] ->
      flags.flag_record <- false;
      ""
    | "if" :: cond ->
        flags.flag_skipper := ( not ( eval_cond p cond ) ) :: (!)
                                flags.flag_skipper;
        ""
    | [ "else" ] ->
        flags.flag_skipper := ( match (!) flags.flag_skipper with
            | cond :: tail -> ( not cond ) :: tail
            | [] -> failwith "else without if");
        ""
    | [ "fi" ] ->
        flags.flag_skipper := ( match (!) flags.flag_skipper with
            | _ :: tail -> tail
            | [] -> failwith "fi without if");
        ""
    | _ ->
      Printf.eprintf "Warning: unknown flag %S\n%!" s;
      ""
  in
  bracket flags

let flags_encoding =
  EzToml.encoding
    ~to_toml:(fun _ -> assert false)
    ~of_toml:(fun ~key v ->
        let table = EzToml.expect_table ~key ~name:"flags" v in
        let flags = { default_flags with flag_file = "" } in
        EzToml.iter
          (fun k v ->
             let key = key @ [ k ] in
             match k with
             | "file" ->
                 flags.flag_file <- EzToml.expect_string ~key v
             | "create" ->
                 flags.flag_create <- EzToml.expect_bool ~key v
             | "record" ->
                 flags.flag_record <- EzToml.expect_bool ~key v
             | "skips" ->
                 flags.flag_skips <- EzToml.expect_string_list ~key v
             | "skip" ->
                 flags.flag_skip <- EzToml.expect_bool ~key v
             | "subst" ->
                 flags.flag_subst <- EzToml.expect_bool ~key v
             | _ ->
                 Printf.eprintf "Warning: discarding flags field %S\n%!"
                   (EzToml.key2str key)
          )
          table;
        flags
      )

let load_skeleton ~dir ~toml ~kind =
  let table =
    match EzToml.from_file toml with
    | `Ok table -> table
    | `Error _ -> Error.raise "Could not parse skeleton file %S" toml
  in

  let name = EzToml.get_string table [ "skeleton"; "name" ] in
  let skeleton_inherits =
    EzToml.get_string_option table [ "skeleton"; "inherits" ]
  in
  let skeleton_toml =
    let file = dir // (kind ^ ".toml") in
    if Sys.file_exists file then
      [ EzFile.read_file file ]
    else begin
      Printf.eprintf "Warning: file %s does not exist\n%!" file;
      []
    end
  in
  let skeleton_files =
    let dir = dir // "files" in
    if not ( Sys.file_exists dir ) then begin
      if !Globals.verbosity > 1 then
        Printf.eprintf "Warning: missing files dir %s\n%!" dir;
      []
    end else
      let files = ref [] in
      EzFile.make_select EzFile.iter_dir ~deep:true dir ~kinds:[ S_REG; S_LNK ]
        ~f:(fun path ->
            if not ( Filename.check_suffix path "~" ) then
              let content = EzFile.read_file (dir // path) in
              files := (path, content) :: !files);
      !files
  in
  let skeleton_flags = EzToml.get_encoding_default
      (EzToml.ENCODING.stringMap flags_encoding) table [ "file" ]
      StringMap.empty  in
  (*  Printf.eprintf "Loaded %s skeleton %s\n%!" kind name; *)
  (name, { skeleton_toml; skeleton_inherits; skeleton_files ; skeleton_flags })

let load_dir_skeletons map kind dir =
  if Sys.file_exists dir then begin
    let map = ref map in
    EzFile.iter_dir dir ~f:(fun file ->
        let dir = dir // file in
        let toml = dir // "skeleton.toml" in
        if Sys.file_exists toml then
          let name, skeleton = load_skeleton ~dir ~toml ~kind in
          if !Globals.verbosity > 0 &&  StringMap.mem name !map then
            Printf.eprintf "Warning: %s skeleton %S overwritten in %s\n%!"
              kind name dir;
          map := StringMap.add name skeleton !map
      );
    !map
  end else
    map

let kind_dir ~kind = "skeletons" // kind ^ "s"

let load_skeletons map kind =
  let map =
    match Config.share_dir () with
    | Some dir ->
        let global_skeletons_dir = dir // kind_dir ~kind in
        load_dir_skeletons map kind global_skeletons_dir
    | None ->
        Printf.eprintf "Warning: could not load skeletons from share/%s/skeletons/%s\n%!" Globals.command kind;
        map
  in
  let user_skeletons_dir = Globals.config_dir // kind_dir ~kind in
  load_dir_skeletons map kind user_skeletons_dir

let builtin_project_skeletons = StringMap.of_list []
let builtin_package_skeletons = StringMap.of_list []

let project_skeletons =
  lazy (load_skeletons builtin_project_skeletons "project")

let package_skeletons =
  lazy (load_skeletons builtin_package_skeletons "package")

let rec inherit_files self_files super_files =
  match (self_files, super_files) with
  | _, [] -> self_files
  | [], _ -> super_files
  | ( (self_file, self_content) :: self_files_tail,
      (super_file, super_content) :: super_files_tail ) ->
    if self_file = super_file then
      (self_file, self_content)
      :: inherit_files self_files_tail super_files_tail
    else if self_file < super_file then
      (self_file, self_content) :: inherit_files self_files_tail super_files
    else
      (super_file, super_content) :: inherit_files self_files super_files_tail

let lookup_skeleton skeletons name =
  let skeletons = Lazy.force skeletons in
  let rec iter name =
    match StringMap.find name skeletons with
    | exception Not_found -> Error.raise "Missing skeleton %S" name
    | self -> (
      match self.skeleton_inherits with
      | None -> self
      | Some super ->
        let super = iter super in
        let skeleton_toml = self.skeleton_toml @ super.skeleton_toml in
        let skeleton_files =
          inherit_files self.skeleton_files super.skeleton_files
        in
        { skeleton_inherits = None; skeleton_toml; skeleton_files ;
          skeleton_flags =
            StringMap.union (fun _ x _ -> Some x)
              self.skeleton_flags super.skeleton_flags } )
  in
  iter name

let backup_skeleton file content =
  let skeleton_dir = Globals.drom_dir // "skeleton" in
  let drom_file = skeleton_dir // file in
  EzFile.make_dir ~p:true (Filename.dirname drom_file);
  EzFile.write_file drom_file content

let project_skeleton = function
  | None -> "program"
  | Some skeleton -> skeleton

let package_skeleton package =
  match package.p_skeleton with
  | Some skeleton -> skeleton
  | None -> Misc.string_of_kind package.kind

let lookup_project skeleton =
  lookup_skeleton project_skeletons (project_skeleton skeleton)

let lookup_package skeleton = lookup_skeleton package_skeletons skeleton

let rec eval_project_cond p cond =
  match cond with
  | [ "skeleton" ; "is" ; skeleton ] ->
      project_skeleton p.skeleton = skeleton
  | [ "skip" ;  skip ] -> List.mem skip p.skip
  | [ "gen" ;  skip ] -> not ( List.mem skip p.skip )
  | "not" :: cond -> not ( eval_project_cond p cond )
  | [ "true" ] -> true
  | [ "false" ] -> false
  | _ ->
      Printf.kprintf failwith "eval_project_cond: unknown condition %S\n%!"
        ( String.concat ":" cond )

let rec eval_package_cond p cond =
  match cond with
  | [ "skeleton" ; "is" ; skeleton ] ->
      package_skeleton p = skeleton
  | [ "kind" ; "is" ; kind ] -> kind = Misc.string_of_kind p.kind
  | [ "pack" ] -> Misc.p_pack_modules p
  | [ "skip" ;  skip ] -> List.mem skip p.project.skip
  | [ "gen" ;  skip ] -> not ( List.mem skip p.project.skip )
  | "not" :: cond -> not ( eval_package_cond p cond )
  | [ "true" ] -> true
  | [ "false" ] -> false
  | _ ->
      Printf.kprintf failwith "eval_package_cond: unknown condition %S\n%!"
        ( String.concat ":" cond )

let skeleton_flags skeleton file =
  try
    let flags =
      try
        StringMap.find file skeleton.skeleton_flags
      with
      (* This is absurd: toml.5.0.0 does not treat quoted keys and
         unquoted keys internally in the same way... *)
        Not_found ->
          StringMap.find ( Printf.sprintf "\"%s\"" file )
            skeleton.skeleton_flags
    in
    if flags.flag_file = "" then
      { flags with flag_file = file ; flag_skipper = ref [] }
    else
      { flags with flag_skipper = ref [] }
  with Not_found ->
    { default_flags with flag_file = file ; flag_skipper = ref [] }

let write_project_files write_file p =
  let skeleton = lookup_project p.skeleton in
  List.iter
    (fun (file, content) ->
      backup_skeleton file content;

      let flags = skeleton_flags skeleton file in
      let bracket = bracket flags eval_project_cond in
      let content =
        if flags.flag_subst then
          try Subst.project () ~bracket ~skipper:flags.flag_skipper p content
          with Not_found ->
            Printf.kprintf failwith "Exception Not_found in %S\n%!" file;
        else content
      in
      let { flag_file;
            flag_create = create;
            flag_skips = skips;
            flag_record = record;
            flag_skip = skip;
            flag_skipper= _ ;
            flag_subst = _ ; } = flags in
      write_file flag_file ~create ~skips ~content ~record ~skip)
    skeleton.skeleton_files;
  ()

let write_package_files write_file package =
  let skeleton = lookup_package (package_skeleton package) in

  List.iter
    (fun (file, content) ->
       backup_skeleton file content;
       let flags = skeleton_flags skeleton file in
       let bracket = bracket flags eval_package_cond in
       let content =
         if flags.flag_subst then
           try
             Subst.package () ~bracket
               ~skipper:flags.flag_skipper package content
           with Not_found ->
             Printf.kprintf failwith "Exception Not_found in %S\n%!" file
         else
           content
       in
       let { flag_file;
             flag_create = create;
             flag_skips = skips;
             flag_record = record;
             flag_skip = skip;
             flag_skipper= _ ;
             flag_subst = _ ; } = flags in
       let file = package.dir // flag_file in
       write_file file ~create ~skips ~content ~record ~skip)
    skeleton.skeleton_files

let write_files write_file p =
  write_project_files write_file p;

  List.iter (fun package -> write_package_files write_file package) p.packages

let project_skeletons () =
  Lazy.force project_skeletons |> StringMap.to_list |> List.map fst

let package_skeletons () =
  Lazy.force package_skeletons |> StringMap.to_list |> List.map fst

let known_skeletons () =
  Printf.sprintf "project skeletons: %s\npackage skeletons: %s\n"
    (String.concat " " ( project_skeletons ()) )
    (String.concat " " ( package_skeletons ()) )
