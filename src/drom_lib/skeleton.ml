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
    | "elif" :: cond ->
        flags.flag_skipper := ( match (!) flags.flag_skipper with
            | _cond :: tail -> ( not (eval_cond p cond) ) :: tail
            | [] -> failwith "elif without if");
        ""
    | [ "fi" | "endif" ] ->
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

let load_skeleton ~drom ~dir ~toml ~kind =
  let table =
    match EzToml.from_file toml with
    | `Ok table -> table
    | `Error _ -> Error.raise "Could not parse skeleton file %S" toml
  in

  let name = try
      EzToml.get_string table [ "skeleton"; "name" ]
    with Not_found ->
      failwith "load_skeleton: wrong or missing key skeleton.name"
  in
  let skeleton_inherits =
    EzToml.get_string_option table [ "skeleton"; "inherits" ]
  in
  let skeleton_toml =
    let basename =
      if kind = "project" then "drom.toml" else
      if kind = "package" then "package.toml" else
        assert false
    in
    let file = dir // basename in
    if Sys.file_exists file then
      [ EzFile.read_file file ]
    else begin
      Printf.eprintf "Warning: file %s does not exist\n%!" file;
      []
    end
  in
  let skeleton_files =
    let files = ref [] in
    EzFile.make_select EzFile.iter_dir ~deep:true dir ~kinds:[ S_REG; S_LNK ]
      ~f:(fun path ->
          match String.lowercase ( Filename.basename path ) with
          | "drom.toml"
          | "package.toml"
          | "skeleton.toml" -> ()
          | _ ->
              if not ( Filename.check_suffix path "~" ) then
                let filename = dir // path in
                let content = EzFile.read_file filename in
                let st = Unix.lstat filename in
                let mode = st.Unix.st_perm in
                files := (path, content, mode) :: !files);
    !files
  in
  let skeleton_flags = EzToml.get_encoding_default
      (EzToml.ENCODING.stringMap flags_encoding) table [ "file" ]
      StringMap.empty  in
  begin
    match EzToml.get table [ "files" ] with
    | exception Not_found -> ()
    | _ ->
        Printf.eprintf
          "Warning: %s skeleton %S has an entry [files], probably instead of [file]\n%!"
          kind name
  end;
  (*  Printf.eprintf "Loaded %s skeleton %s\n%!" kind name; *)
  (name, { skeleton_toml;
           skeleton_inherits;
           skeleton_files ;
           skeleton_flags ;
           skeleton_drom = drom;
           skeleton_name = name;
         })

let load_dir_skeletons ~drom map kind dir =
  if Sys.file_exists dir then begin
    let map = ref map in
    EzFile.iter_dir dir ~f:(fun file ->
        let dir = dir // file in
        let toml = dir // "skeleton.toml" in
        if Sys.file_exists toml then
          try
            let name, skeleton = load_skeleton ~drom ~dir ~toml ~kind in
            if !Globals.verbosity > 0 &&  StringMap.mem name !map then
              Printf.eprintf "Warning: %s skeleton %S overwritten in %s\n%!"
                kind name dir;
            map := StringMap.add name skeleton !map
          with exn ->
            Printf.eprintf "Warning: could not load %s skeleton from %S, exception:\n%S\n%!" kind dir (Printexc.to_string exn)
      );
    !map
  end else
    map

let kind_dir ~kind = "skeletons" // kind ^ "s"

let load_system_skeletons map kind =
    match Config.share_dir () with
    | Some dir ->
        let global_skeletons_dir = dir // kind_dir ~kind in
        load_dir_skeletons ~drom:true map kind global_skeletons_dir
    | None ->
        Printf.eprintf "Warning: could not load skeletons from share/%s/skeletons/%s\n%!" Globals.command kind;
        map

let load_user_skeletons map kind =
  let user_skeletons_dir = Globals.config_dir // kind_dir ~kind in
  load_dir_skeletons ~drom:false map kind user_skeletons_dir

let load_skeletons kind =
  let map = load_system_skeletons StringMap.empty kind in
  load_user_skeletons map kind

let project_skeletons = lazy (load_skeletons "project")

let package_skeletons = lazy (load_skeletons "package")

let rec inherit_files self_files super_files =
  match (self_files, super_files) with
  | _, [] -> self_files
  | [], _ -> super_files
  | ( (self_file, self_content, self_mode) :: self_files_tail,
      (super_file, super_content, super_mode) :: super_files_tail ) ->
    if self_file = super_file then
      (self_file, self_content, self_mode)
      :: inherit_files self_files_tail super_files_tail
    else if self_file < super_file then
      (self_file, self_content, self_mode) ::
      inherit_files self_files_tail super_files
    else
      (super_file, super_content, super_mode)
      :: inherit_files self_files super_files_tail

let lookup_skeleton ?(project=false) skeletons name =
  let skeletons = Lazy.force skeletons in
  let rec iter name =
    match StringMap.find name skeletons with
    | exception Not_found -> download_skeleton name
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
            let skeleton_flags =
              StringMap.union (fun _ x _ -> Some x)
                self.skeleton_flags super.skeleton_flags
            in
            { skeleton_name = name;
              skeleton_inherits = None;
              skeleton_toml; skeleton_files ;
              skeleton_drom = false;
              skeleton_flags ;
            }

  and download_skeleton name =
    if project then
      match EzString.chop_prefix name ~prefix:"gh:" with
      | None ->
          Error.raise "Missing skeleton %S" name
      | Some github_project ->
          let url = Printf.sprintf "https://github.com/%s/tarball/master"
              github_project in
          let output = Filename.temp_file "archive" ".tgz" in
          Misc.wget ~url ~output;
          let basedir = Printf.sprintf "gh-%s"
              ( Digest.string name |> Digest.to_hex ) in
          let dir = Globals.config_dir // "skeletons"
                    // "projects" // basedir in
          EzFile.make_dir ~p:true dir;
          Misc.call [| "tar" ; "zxf"; output ;
                       "--strip-components=1"; "-C"; dir |];
          let toml = dir // "skeleton.toml" in
          if not ( Sys.file_exists toml ) then
            EzFile.write_file toml
              ( Printf.sprintf {|[skeleton]
name = "%s"
|} name );
          let (skel_name, skeleton) =
            load_skeleton ~drom:false ~dir ~toml ~kind:"project"
          in
          if skel_name = name then
            skeleton
          else
            Error.raise "Wrong remote skeleton %S instead of %S in %s\n"
              skel_name name dir
    else
      Error.raise "Missing skeleton %S" name
  in
  iter name

let backup_skeleton file content ~perm =
  let skeleton_dir = Globals.drom_dir // "skeleton" in
  let drom_file = skeleton_dir // file in
  EzFile.make_dir ~p:true (Filename.dirname drom_file);
  EzFile.write_file drom_file content;
  Unix.chmod drom_file perm

let lookup_project skeleton =
  lookup_skeleton ~project:true
    project_skeletons (Misc.project_skeleton skeleton)

let lookup_package skeleton = lookup_skeleton package_skeletons skeleton

let rec eval_project_cond p cond =
  match cond with
  | [ "skeleton" ; "is" ; skeleton ] ->
      Misc.project_skeleton p.skeleton = skeleton
  | [ "skip" ;  skip ] -> List.mem skip p.skip
  | [ "gen" ;  skip ] -> not ( List.mem skip p.skip )
  | "not" :: cond -> not ( eval_project_cond p cond )
  | [ "true" ] -> true
  | [ "false" ] -> false
  | [ "ci" ; system ] -> List.mem system p.ci_systems
  | [ "github-organization"] -> p.github_organization <> None
  | [ "homepage"] -> Misc.homepage p <> None
  | [ "copyright"] -> p.copyright <> None
  | [ "bug-reports"] -> Misc.bug_reports p <> None
  | [ "dev-repo"] -> Misc.dev_repo p <> None
  | [ "doc-gen"] -> Misc.doc_gen p <> None
  | [ "doc-api"] -> Misc.doc_api p <> None
  | [ "sphinx-target"] -> p.sphinx_target <> None
  | [ "profile"] -> p.profile <> None
  | [ "min-edition" ] -> p.min_edition <> p.edition
  | [ "field" ; name ] -> StringMap.mem name p.fields
  | "field" :: name :: v ->
      let v = String.concat ":" v in
      begin
        match StringMap.find name p.fields with
        | exception Not_found -> false
        | x -> x = v
      end

  | _ ->
      Printf.kprintf failwith "eval_project_cond: unknown condition %S\n%!"
        ( String.concat ":" cond )

let rec eval_package_cond p cond =
  match cond with
  | [ "skeleton" ; "is" ; skeleton ] ->
      Misc.package_skeleton p = skeleton
  | [ "kind" ; "is" ; kind ] -> kind = Misc.string_of_kind p.kind
  | [ "pack" ] -> Misc.p_pack_modules p
  | [ "skip" ;  skip ] -> List.mem skip p.project.skip
  | [ "gen" ;  skip ] -> not ( List.mem skip p.project.skip )
  | "not" :: cond -> not ( eval_package_cond p cond )
  | [ "true" ] -> true
  | [ "false" ] -> false
  | "project" :: cond -> eval_project_cond p.project cond

  | [ "field" ; name ] -> StringMap.mem name p.p_fields
  | "field" :: name :: v ->
      let v = String.concat ":" v in
      begin
        match StringMap.find name p.p_fields with
        | exception Not_found -> false
        | x -> x = v
      end

  | _ ->
      Printf.kprintf failwith "eval_package_cond: unknown condition %S\n%!"
        ( String.concat ":" cond )

let default_flags flag_file =
  { default_flags with flag_file ; flag_skipper = ref [] }

let skeleton_flags skeleton file =
  try
    let flags =
      try
        StringMap.find file skeleton.skeleton_flags
      with
      (* This is absurd: toml.5.0.0 does not treat quoted keys and
         unquoted keys internally in the same way... *)
        Not_found ->
          try
            StringMap.find ( Printf.sprintf "\"%s\"" file )
              skeleton.skeleton_flags
          with
            Not_found ->
              if Misc.verbose 2 then
                Printf.eprintf "skeleton %S has no flags for file %S\n%!"
                  skeleton.skeleton_name file;
              raise Not_found
    in
    if flags.flag_file = "" then
      { flags with flag_file = file ; flag_skipper = ref [] }
    else
      { flags with flag_skipper = ref [] }
  with Not_found ->
    default_flags file

let write_project_files write_file p =
  let skeleton = lookup_project p.skeleton in
  List.iter
    (fun (file, content, perm) ->
       (* Printf.eprintf "File %s perm %o\n%!" file perm; *)
      backup_skeleton file content ~perm;

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
      write_file flag_file ~create ~skips ~content ~record ~skip ~perm;
    )
    skeleton.skeleton_files;
  ()

let subst_package_file flags content package =
  let bracket = bracket flags eval_package_cond in
  let content =
    if flags.flag_subst then
      try
        Subst.package () ~bracket
          ~skipper:flags.flag_skipper package content
      with Not_found ->
        Printf.kprintf failwith "Exception Not_found in %S\n%!"
          flags.flag_file
    else
      content
  in
  content

let write_package_files write_file package =
  let skeleton = lookup_package (Misc.package_skeleton package) in

  List.iter
    (fun (file, content, perm) ->
       (* Printf.eprintf "File %s perm %o\n%!" file perm; *)
       backup_skeleton file content ~perm;
       let flags = skeleton_flags skeleton file in
       let content = subst_package_file flags content package in
       let { flag_file;
             flag_create = create;
             flag_skips = skips;
             flag_record = record;
             flag_skip = skip;
             flag_skipper= _ ;
             flag_subst = _ ; } = flags in
       let file = package.dir // flag_file in
       write_file file ~create ~skips ~content ~record ~skip ~perm)
    skeleton.skeleton_files

let write_files write_file p =
  write_project_files write_file p;
  List.iter (fun package -> write_package_files write_file package) p.packages

let write_files ~twice write_file p =
  write_files write_file p;
  if twice then
    (* We need to iterate a second time, because some files may not have
       been present during the first iteration. For example, the `dune`
       file will not be correct if some source files were not yet
       created from the template when it was created. *)
    write_files write_file p;
  ()

let project_skeletons () =
  Lazy.force project_skeletons |> StringMap.to_list |> List.map snd

let package_skeletons () =
  Lazy.force package_skeletons |> StringMap.to_list |> List.map snd

let known_skeletons () =
  Printf.sprintf "project skeletons: %s\npackage skeletons: %s\n"
    (project_skeletons ()
     |> List.map (fun s -> s.skeleton_name)
     |> String.concat " " )
    (package_skeletons ()
     |> List.map (fun s -> s.skeleton_name)
     |> String.concat " " )
