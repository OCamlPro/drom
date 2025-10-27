(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Ezcmd.V2
open EZCMD.TYPES
open Ez_file.V1
open EzFile.OP
open EzCompat

open Types

exception Skip

let default_args ~share_args () =
  { arg_upgrade = false;
    arg_force = false;
    arg_diff = false;
    arg_skip = [];
    arg_promote_skip = false;
    arg_edition = None;
    arg_min_edition = None;
    arg_create = None ;

    arg_share = share_args ;
  }

let args ?(set_share=false) () =
  let share_args, share_specs = Share.args ~set:set_share () in
  let args = default_args ~share_args () in
  let specs =
    [ ( [ "f"; "force" ],
        Arg.Unit (fun () -> args.arg_force <- true),
        EZCMD.info
          "Force overwriting modified files (otherwise, they would be skipped)"
      );
      ( [ "skip" ],
        Arg.String
          (fun s ->
            args.arg_skip <- (true, s) :: args.arg_skip;
            args.arg_upgrade <- true ),
        EZCMD.info ~docv:"FILE" "Add $(docv) to skip list" );
      ( [ "unskip" ],
        Arg.String
          (fun s ->
            args.arg_skip <- (false, s) :: args.arg_skip;
            args.arg_upgrade <- true ),
        EZCMD.info ~docv:"FILE" "Remove $(docv) from skip list" );
      ( [ "diff" ],
        Arg.Unit (fun () -> args.arg_diff <- true),
        EZCMD.info "Print a diff of user-modified files that are being skipped"
      );
      ( [ "promote-skip" ],
        Arg.Unit (fun () -> args.arg_promote_skip <- true),
        EZCMD.info "Promote user-modified files to skip field" );
      ( [ "edition" ],
        Arg.String (fun s -> args.arg_edition <- Some s),
        EZCMD.info ~docv:"OCAMLVERSION" "Set project default OCaml version" );
      ( [ "min-edition" ],
        Arg.String (fun s -> args.arg_min_edition <- Some s),
        EZCMD.info ~docv:"OCAMLVERSION" "Set project minimal OCaml version" );
      ( [ "create" ],
        Arg.String (function
              "true" -> args.arg_create <- Some true
            | "false" -> args.arg_create <- Some false
            | s ->
                Printf.eprintf "Error: invalid argument %S to option '--create BOOL'\n%!" s;
                exit 2
          ),
        EZCMD.info ~docv:"BOOL"
          "Change project creation status" );
    ]
  in
  (args, specs @ share_specs)

let compute_config_hash files =
  let files = List.sort compare files in
  let files =
    List.map
      (fun (file, content) -> (file, Hashes.digest_content ~file ~content () |> Hashes.to_string ))
      files
  in
  let to_hash =
    String.concat "?"
      (List.map (fun (file, hash) -> Printf.sprintf "%s^%s" file hash) files)
  in
  Hashes.digest_content ~file:"" ~content:to_hash ()

let update_files share ?update_args ?(git = false) p =
  (*
  let force, upgrade, skip, diff, promote_skip, edition, min_edition =
    match args with
    | None -> (false, false, [], false, false)
    | Some args ->
        (args.arg_force, args.arg_upgrade, args.arg_skip, args.arg_diff,
         args.arg_promote_skip)
  in
*)
  let args =
    match update_args with
    | None -> default_args ~share_args:(Share.default_args ()) ()
    | Some args -> args
  in
  let share_args = args.arg_share in
  let changed = false in
  let p, changed =
    match args.arg_skip with
    | [] -> (p, changed)
    | skip ->
        let skip =
          List.fold_left
            (fun skips (bool, elem) ->
               if bool then
                 elem :: skips
               else
                 EzList.remove elem skips )
            p.skip skip
        in
        let p = { p with skip } in
        (p, true)
  in

  let p, changed =
    match args.arg_edition with
    | None -> (p, changed)
    | Some edition -> ({ p with edition }, true)
  in

  let p, changed =
    match args.arg_create with
    | None -> (p, changed)
    | Some bool ->
        if p.project_create = bool then
          (p, changed)
        else
          ({ p with project_create = bool }, true)
  in

  let p, changed =
    match args.arg_min_edition with
    | None -> (p, changed)
    | Some min_edition -> ({ p with min_edition }, true)
  in
  let p, changed =
    match args, p with
      { arg_share = { arg_share_version = Some "0.8.0";
                      arg_share_repo = None ; _ } ; _ },
      { project_share_version = (None | Some "0.8.0");
        project_share_repo = None ; _ } ->
        p, changed     (* do nothing for compatibility with version = 0.8.0 *)
    | _ ->
        let p, changed =
          match args.arg_share.arg_share_version with
          | None -> (p, changed)
          | Some arg_share_version ->
              if args.arg_share.arg_share_version <> p.project_share_version then
                let project_share_repo = match p.project_share_repo with
                  | None -> Some ( Share.share_repo_default () )
                  | Some project_share_repo -> Some project_share_repo
                in
                let project_share_version = Some arg_share_version in
                ({ p with project_share_version ; project_share_repo }, true)
              else
                (p, changed)
        in
        match share_args.arg_share_repo with
        | None -> (p, changed)
        | project_share_repo ->
            if share_args.arg_share_repo <> p.project_share_repo then
              ({ p with project_share_repo }, true)
            else
              (p, changed)
  in
  let create_phase = p.project_create in

  let can_skip = ref [] in

  let skip_set = ref StringSet.empty in
  List.iter (fun skip -> skip_set := StringSet.add skip !skip_set) p.skip;
  List.iter
    (fun pk ->
       match pk.p_skip with
       | None -> ()
       | Some list ->
           List.iter
             (fun skip ->
                skip_set := StringSet.add (Filename.concat pk.dir skip) !skip_set )
             list )
    p.packages;
  let skip_set = !skip_set in
  let not_skipped s =
    can_skip := s :: !can_skip;
    not (StringSet.mem s skip_set)
  in
  let skipped = ref [] in
  let write_file ?(record = true) ~perm hashes filename content =
    Hashes.write hashes ~record ~perm ~file:filename ~content
  in
  let can_update ~filename ~perm hashes content =
    let old_content = EzFile.read_file filename in
    let old_perm = (Unix.lstat filename).Unix.st_perm in
    if content = old_content && Hashes.perm_equal perm old_perm then begin
      begin
        match Hashes.get hashes filename with
        | exception Not_found ->
            Printf.eprintf "Warning: .drom: missing hash for %S\n%!" filename;
            let hash =
              Hashes.digest_content ~file:filename ~perm:old_perm
                ~content:old_content ()
            in
            Hashes.update ~git:false hashes filename [hash]
        | _ -> ()
      end;
      false
    end else
      args.arg_force
      ||
      match Hashes.get hashes filename with
      | exception Not_found ->
          skipped := filename :: !skipped;
          Printf.eprintf "Skipping existing file %s\n%!" filename;
          false
      | former_hashes ->
          let hash =
            Hashes.digest_content ~file:filename ~perm:old_perm ~content:old_content ()
          in
          let modified =
            List.for_all ((<>) hash) former_hashes
            && (* compatibility with former hashing system *)
            let old_hash = Hashes.old_string_hash old_content in
            List.for_all ((<>) old_hash) former_hashes
          in
          if modified then (
            skipped := filename :: !skipped;
            Printf.eprintf "Skipping modified file %s\n%!" filename;
            if args.arg_diff then begin
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
              ( try Call.call [ "diff"; "-u"; file_a; file_b ] with
                | _ -> () );
              Sys.remove file_a;
              Sys.remove file_b
            end
          );
          not modified
  in

  let write_file
      ?((* add to git/.drom *) record = true)
      ?((* only create, never update *) create = false)
      ?((* force to skip *) skip = false)
      ?((* force to write *) force = false)
      ?((* tests for skipping *) skips = [])
      ?(perm = 0o644)
      hashes
      filename
      content =
    try
      if create && not create_phase then raise Skip;
      if skip then raise Skip;
      if force then (
        Printf.eprintf "Forced Update of file %s\n%!" filename;
        write_file hashes filename content ~perm
      ) else if
        (* the file should not be to skip *)
        not_skipped filename
        && (* all tags attached to this file should also not be to skip *)
        List.for_all not_skipped skips
      then
        if not record then
          write_file ~record:false hashes filename content ~perm
        else if not (Sys.file_exists filename) then (
          if Globals.verbose 2 then
            Printf.eprintf "Creating file %s\n%!" filename;
          write_file hashes filename content ~perm
        )
        else if can_update ~filename ~perm hashes content then (
          Printf.eprintf "Updating file %s\n%!" filename;
          write_file hashes filename content ~perm
        ) else
          raise Skip
      else
        raise Skip
    with
    | Skip ->
        let filename = "_drom" // "skipped" // filename in
        EzFile.make_dir ~p:true (Filename.dirname filename);
        EzFile.write_file filename content
  in

  let config = Config.get () in

  let p, changed =
    if args.arg_upgrade then
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

      begin
        match p.project_share_version with
        | Some _ ->
            Hashes.set_version hashes "0.9.0"
        | None -> ()
      end;

      if create_phase then
        if git && not (Sys.file_exists ".git") then (
          Git.call "init" [ "-q" ];
          match config.config_github_organization with
          | None -> ()
          | Some organization ->
              Git.call
                "remote"
                [
                  "add";
                  "origin";
                  Printf.sprintf "git@github.com:%s/%s" organization
                    p.package.name
                ];
              if Sys.file_exists "README.md" then
                Git.call "add" [ "README.md" ];
              Git.call "commit" [ "--allow-empty"; "-m"; "Initial commit" ]
        );

      List.iter
        (fun package ->
           let gen_opam_file =
             match package.kind with
             | Virtual -> (
                 match StringMap.find "gen-opam" package.p_fields with
                 | exception _ -> false
                 | s -> (
                     match String.lowercase s with
                     | "all"
                     | "some" ->
                         true
                     | _ -> false ) )
             | _ -> true
           in
           if gen_opam_file then (
             let opam_filename = package.name ^ ".opam" in
             ( match package.p_gen_version with
               | None -> ()
               | Some file ->
                   (* TODO : we should put info in this file *)
                   let version_file = package.dir // file in
                   if Sys.file_exists version_file then Sys.remove version_file;
                   write_file hashes (version_file ^ "t")
                     (GenVersion.file package file) );
             EzFile.make_dir ~p:true "opam";
             let full_filename = "opam" // opam_filename in
             write_file hashes full_filename
               (Opam.opam_of_package Single share package);
             if Sys.file_exists opam_filename then begin
               Printf.eprintf "Removing deprecated %s (moved to %s)\n%!"
                 opam_filename full_filename;
               Hashes.remove hashes opam_filename
             end
           ) )
        p.packages;
      EzFile.make_dir ~p:true Globals.drom_dir;

      EzFile.write_file
        (Globals.drom_dir // "known-licences.txt")
        (License.known_licenses share);

      EzFile.write_file
        (Globals.drom_dir // "known-skeletons.txt")
        (Skeleton.known_skeletons share);

      EzFile.write_file (Globals.drom_dir // "header.ml") (License.header_ml share p);
      EzFile.write_file
        (Globals.drom_dir // "header.mll")
        (License.header_mll share p);
      EzFile.write_file
        (Globals.drom_dir // "header.mly")
        (License.header_mly share p);

      EzFile.write_file
        (Globals.drom_dir // "maximum-skip-field.txt")
        (Printf.sprintf "skip = \"%s\"\n" (String.concat " " !can_skip));

      (* Most of the files are created using Skeleton *)
      Skeleton.write_files
        (fun file ~create ~skips ~content ~record ~skip ~perm ->
           write_file hashes ~perm file ~create ~skips ~record ~skip content )
        ( Subst.state ~hashes () share p );

      let p, changed =
        if args.arg_promote_skip && !skipped <> [] then (
          let skip = p.skip @ !skipped in
          Printf.eprintf "skip field promotion: %s\n%!"
            (String.concat " " !skipped);
          ({ p with skip }, true)
        ) else
          (p, changed)
      in

      let upgrade = args.arg_upgrade || changed in
      let skip = not (upgrade || not (Sys.file_exists "drom.toml")) in
      let files = Project.to_files share p in
      let files =
        List.map
          (fun (file, content) ->
             let content =
               if upgrade then begin
                 write_file ~skip ~force:upgrade hashes file content;
                 content
               end else
                 try EzFile.read_file file with
                 | Sys_error _ -> ""
             in
             (file, content) )
          files
      in

      let hash = compute_config_hash files in

      (* Save the "hash of all files", i.e. the hash of the drom.toml
         file that was used to generate all other files, to be able to
         detect need for update. We use '.' for the associated name,
         because it must be an existent file, otherwise `Hashes.save`
         will discard it. *)
      Hashes.update ~git:false hashes "." [hash];
      p
    )

let display_create_warning p =
  if p.project_create then begin
    Printf.eprintf "%s\n%!"
      (String.concat "\n" [
          "Warning: this project is still in creation mode, where more files" ;
          "  are managed by 'drom'. Use the command:";
          "drom project --create false";
          "  to mark the project as created and switch to light management.";
        ])
  end

let update_files share ~twice ?(warning=true) ?update_args ?(git = false) p =
  let p_final = update_files share ?update_args ~git p in
  if twice then begin
    Printf.eprintf "Re-iterating file generation for consistency...\n%!";
    let _p_final2 = update_files share ?update_args ~git p in
    ()
  end;
  if warning then display_create_warning p_final
