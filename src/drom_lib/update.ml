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
open Ezcmd.V2
open EZCMD.TYPES
open EzFile.OP
open EzCompat

exception Skip

type update_args =
  { mutable arg_upgrade : bool;
    mutable arg_force : bool;
    mutable arg_diff : bool;
    mutable arg_skip : (bool * string) list;
    mutable arg_promote_skip : bool ;
  }

let update_args () =
  let args =
    { arg_upgrade = false; arg_force = false; arg_diff = false;
      arg_skip = [] ; arg_promote_skip = false }
  in
  let specs =
    [ ( [ "f" ; "force" ],
        Arg.Unit (fun () -> args.arg_force <- true),
        EZCMD.info "Force overwriting modified files (otherwise, they would be skipped)" );
      ( [ "skip" ],
        Arg.String
          (fun s ->
            args.arg_skip <- (true, s) :: args.arg_skip;
            args.arg_upgrade <- true),
        EZCMD.info ~docv:"FILE" "Add $(docv) to skip list" );
      ( [ "unskip" ],
        Arg.String
          (fun s ->
            args.arg_skip <- (false, s) :: args.arg_skip;
            args.arg_upgrade <- true),
        EZCMD.info ~docv:"FILE" "Remove $(docv) from skip list" );
      ( [ "diff" ],
        Arg.Unit (fun () -> args.arg_diff <- true),
        EZCMD.info "Print a diff of user-modified files that are being skipped" );
      ( [ "promote-skip" ],
        Arg.Unit (fun () -> args.arg_promote_skip <- true),
        EZCMD.info "Promote user-modified files to skip field" );
    ]
  in
  (args, specs)

let compute_config_hash files =
  let files = List.sort compare files in
  let files =
    List.map (fun (file, content) ->
        (file, Hashes.digest_content ~file content)) files
  in
  let to_hash =
    String.concat "?"
      (List.map (fun (file, hash) -> Printf.sprintf "%s^%s" file hash) files)
  in
  Hashes.digest_content ~file:"" to_hash

let update_files ?args ?(git = false) ?(create = false) p =
  let force, upgrade, skip, diff, promote_skip =
    match args with
    | None -> (false, false, [], false, false)
    | Some args ->
        (args.arg_force, args.arg_upgrade, args.arg_skip, args.arg_diff,
         args.arg_promote_skip)
  in

  let changed = false in
  let p, changed =
    match skip with
    | [] -> (p, changed)
    | skip ->
        let skip =
          List.fold_left
            (fun skips (bool, elem) ->
               if bool then
                 elem :: skips
               else
                 EzList.remove elem skips)
            p.skip skip
        in
        let p = { p with skip } in
        (p, true)
  in

  let can_skip = ref [] in
  let not_skipped s =
    can_skip := s :: !can_skip;
    not (List.mem s p.skip)
  in
  let skipped = ref [] in
  let write_file ?(record = true) ~perm hashes filename content =
    Hashes.write hashes ~record ~perm filename content
  in
  let can_update ~filename ~perm hashes content =
    let old_content = EzFile.read_file filename in
    let old_perm = ( Unix.lstat filename ). Unix.st_perm in
    if content = old_content && Hashes.perm_equal perm old_perm then begin
      false
    end else
      force
      ||
      match Hashes.get hashes filename with
      | exception Not_found ->
          skipped := filename :: !skipped;
          Printf.eprintf "Skipping existing file %s\n%!" filename;
          false
      | former_hash ->
          let hash = Hashes.digest_content
              ~file:filename ~perm:old_perm old_content in
          let modified = former_hash <> hash &&
                         (* compatibility with former hashing system *)
                         former_hash <> Digest.string old_content
          in
          if modified then (
            skipped := filename :: !skipped;
            Printf.eprintf "Skipping modified file %s\n%!" filename;
            if diff then begin
              let basename = Filename.basename filename in
              let dirname = Globals.drom_dir // "temp" in
              let dirname_a = dirname // "a" in
              let dirname_b = dirname // "b" in
              EzFile.make_dir ~p:true dirname_a;
              EzFile.make_dir ~p:true dirname_b;
              let file_a = dirname_a // basename in
              let file_b = dirname_b // basename in
              EzFile.write_file file_a old_content;
              EzFile.write_file file_b content;
              (try Misc.call [| "diff"; "-u"; file_a; file_b |] with _ -> ());
              Sys.remove file_a;
              Sys.remove file_b
            end
          );
          not modified
  in

  let write_file ?((* add to git/.drom *) record = true)
      ?((* only create, never update *) create = false)
      ?((* force to skip *) skip = false) ?((* force to write *) force = false)
      ?((* tests for skipping *) skips = [])
      ?(perm = 0o644)
      hashes filename content =
    try
      if skip then raise Skip;
      if force then (
        Printf.eprintf "Forced Update of file %s\n%!" filename;
        write_file hashes filename content ~perm
      ) else if not_skipped filename && List.for_all not_skipped skips then
        if not record then
          write_file ~record:false hashes filename content ~perm
        else if not (Sys.file_exists filename) then (
          if Misc.verbose 2 then
            Printf.eprintf "Creating file %s\n%!" filename;
          write_file hashes filename content ~perm
        ) else if create then
          raise Skip
        else if can_update ~filename ~perm hashes content then (
          Printf.eprintf "Updating file %s\n%!" filename;
          write_file hashes filename content ~perm
        ) else
          raise Skip
      else
        raise Skip
    with Skip ->
      let filename = "_drom" // "skipped" // filename in
      EzFile.make_dir ~p:true (Filename.dirname filename);
      EzFile.write_file filename content
  in

  let config = Lazy.force Config.config in

  let p, changed =
    if upgrade then
      let p, changed =
        match (p.github_organization, config.config_github_organization) with
        | None, Some s -> ({ p with github_organization = Some s }, true)
        | _ -> (p, changed)
      in
      let p, changed =
        match (p.authors, config.config_author) with
        | [], Some s -> ({ p with authors = [ s ] }, true)
        | _ -> (p, changed)
      in
      let p, changed =
        match (p.copyright, config.config_copyright) with
        | None, Some s -> ({ p with copyright = Some s }, true)
        | _ -> (p, changed)
      in
      (p, changed)
    else
      (p, changed)
  in
  List.iter (fun package -> package.project <- p) p.packages;

  Hashes.with_ctxt ~git (fun hashes ->
      if create then
        if git && not (Sys.file_exists ".git") then (
          Git.call [ "init" ; "-q"];
          match config.config_github_organization with
          | None -> ()
          | Some organization ->
              Git.call
                [ "remote";
                  "add";
                  "origin";
                  Printf.sprintf "git@github.com:%s/%s" organization
                    p.package.name
                ];
              if Sys.file_exists "README.md" then Git.call [ "add"; "README.md" ];
              Git.call [ "commit"; "--allow-empty"; "-m"; "Initial commit" ];
        );

      List.iter
        (fun package ->
           match package.kind with
           | Virtual -> ()
           | _ ->
               ( match package.p_gen_version with
                 | None -> ()
                 | Some file ->
                     (* TODO : we should put info in this file *)
                     let version_file = package.dir // file in
                     if Sys.file_exists version_file then
                       Sys.remove version_file;
                     write_file hashes ( version_file ^ "t")
                       (GenVersion.file package file)
               );
               let opam_filename = package.name ^ ".opam" in
               write_file hashes opam_filename
                 (Opam.opam_of_project Single package))
        p.packages;

      EzFile.make_dir ~p:true Globals.drom_dir;

      EzFile.write_file
        (Globals.drom_dir // "known-licences.txt")
        (License.known_licenses ());

      EzFile.write_file
        (Globals.drom_dir // "known-skeletons.txt")
        (Skeleton.known_skeletons ());

      EzFile.write_file (Globals.drom_dir // "header.ml") (License.header_ml p);
      EzFile.write_file
        (Globals.drom_dir // "header.mll")
        (License.header_mll p);
      EzFile.write_file
        (Globals.drom_dir // "header.mly")
        (License.header_mly p);

      EzFile.write_file
        (Globals.drom_dir // "maximum-skip-field.txt")
        (Printf.sprintf "skip = \"%s\"\n" (String.concat " " !can_skip));

      (* Most of the files are created using Skeleton *)
      Skeleton.write_files
        (fun file ~create ~skips ~content ~record ~skip ~perm ->
           write_file hashes ~perm file ~create ~skips ~record ~skip content)
        p;

      let p, changed =
        if promote_skip && !skipped <> [] then (
          let skip = p.skip @ !skipped in
          Printf.eprintf "skip field promotion: %s\n%!"
            (String.concat " " !skipped);
          ({ p with skip }, true)
        ) else
          (p, changed)
      in

      let upgrade = upgrade || changed in
      let skip =
        not (upgrade || not (Sys.file_exists "drom.toml"))
      in
      let files = Project.to_files p in
      let files =
        List.map
          (fun (file, content) ->
             let content =
               if upgrade then begin
                 write_file ~skip ~force:upgrade hashes file content;
                 content
               end else try
                   EzFile.read_file file
                 with Sys_error _ -> ""
             in
             (file, content)
          )
          files
      in

      let hash = compute_config_hash files in

      (* Save the "hash of all files", i.e. the hash of the drom.toml
         file that was used to generate all other files, to be able to
         detect need for update. We use '.' for the associated name,
         because it must be an existent file, otherwise `Hashes.save`
         will discard it. *)
      Hashes.update ~git:false hashes "." hash);
  ()

let update_files ~twice ?args ?(git = false) ?(create = false) p =
  update_files ?args ~git ~create p;
  if twice then begin
    Printf.eprintf "Re-iterate file generation for consistency...\n%!";
    update_files ?args ~git p
  end
