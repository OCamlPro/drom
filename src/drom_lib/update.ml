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
open Ezcmd.TYPES
open EzFile.OP
open EzCompat

exception Skip

type update_args = {
  mutable arg_upgrade : bool ;
  mutable arg_force : bool ;
  mutable arg_diff : bool ;
  mutable arg_skip : ( bool * string ) list ;
}

let update_args () =
  let args = {
    arg_upgrade = false;
    arg_force = false;
    arg_diff = false;
    arg_skip = [];
  }
  in
  let specs = [
    ( [ "force" ],
      Arg.Unit (fun () -> args.arg_force <- true),
      Ezcmd.info "Force overwriting files" );
    ( [ "skip" ],
      Arg.String (fun s ->
          args.arg_skip <- (true, s) :: args.arg_skip;
          args.arg_upgrade <- true),
      Ezcmd.info "Add to skip list" );
    ( [ "unskip" ],
      Arg.String (fun s ->
          args.arg_skip <- (false, s) :: args.arg_skip;
          args.arg_upgrade <- true),
      Ezcmd.info "Remove from skip list" );
    ( [ "diff" ],
      Arg.Unit (fun () -> args.arg_diff <- true),
      Ezcmd.info "Print a diff of skipped files" );
  ]
  in
  ( args, specs )

let update_files
    ?args ?mode ?(git = false) ?(create = false)
    ?(promote_skip = false)
    p =
  let (force,upgrade,skip,diff) =
    match args with
    | None -> (false, false, [], false)
    | Some args ->
        (args.arg_force,
         args.arg_upgrade,
         args.arg_skip,
         args.arg_diff)
  in

  let changed = false in
  let (p, changed) =
    match skip with
    | [] -> (p, changed)
    | skip ->
        let skip =
          List.fold_left (fun skips (bool, elem) ->
              if bool then
                elem :: skips
              else
                EzList.remove elem skips
            ) p.skip skip
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
  let write_file ?(record = true) hashes filename content =
    Hashes.write hashes ~record filename content
  in
  let can_update ~filename hashes content =
    let old_content = EzFile.read_file filename in
    if content = old_content then
      false
    else
      begin
        force ||
        let hash = Hashes.digest_string old_content in
        match Hashes.get hashes filename with
        | exception Not_found ->
            skipped := filename :: !skipped;
            Printf.eprintf "Skipping existing file %s\n%!" filename;
            false
        | former_hash ->
            let modified = former_hash <> hash in
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
                ( try Misc.call [| "diff" ; "-u" ; file_a ; file_b |] with
                  | _ -> ());
                Sys.remove file_a;
                Sys.remove file_b;
              end;
            );
            not modified
      end
  in

  let write_file ?(record = true) ?((* add to git *)
      create = false)
      ?((* only create, never update *)
      skip = false) ?((* force to skip *)
      immediate = false) ?((* force to write *)
      skips = []) (* tests for skipping *)
      hashes filename content =
    try
      if skip then raise Skip;
      if immediate then (
        Printf.eprintf "Forced Update of file %s\n%!" filename;
        write_file hashes filename content
      ) else if not_skipped filename && List.for_all not_skipped skips then
        if not record then
          write_file ~record:false hashes filename content
        else if not (Sys.file_exists filename) then (
          Printf.eprintf "Creating file %s\n%!" filename;
          write_file hashes filename content
        ) else if create then
          raise Skip
        else if can_update ~filename hashes content then (
          Printf.eprintf "Updating file %s\n%!" filename;
          write_file hashes filename content
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
  let p, changed =
    match mode with
    | None -> (p, changed)
    | Some mode ->
        let js_dep = ("js_of_ocaml", [ Semantic (3, 6, 0) ]) in
        let js_tool = ("js_of_ocaml", [ Semantic (3, 6, 0) ]) in
        let ppx_tool = ("js_of_ocaml-ppx", [ Semantic (3, 6, 0) ]) in
        let add_dep (name, depversions) deps changed =
          let dep =
            ( name,
              { depversions; depname = None; deptest = false; depdoc = false } )
          in
          match mode with
          | Binary ->
              if List.mem dep deps then
                (EzList.remove dep deps, true)
              else
                (deps, changed)
          | Javascript ->
              if not (List.mem_assoc (fst dep) deps) then
                (dep :: deps, true)
              else
                (deps, changed)
        in
        let dependencies, changed = add_dep js_dep p.dependencies changed in
        let tools, changed = add_dep js_tool p.tools changed in
        let tools, changed = add_dep ppx_tool tools changed in
        ({ p with mode; dependencies; tools }, changed)
  in
  List.iter (fun package -> package.project <- p) p.packages;

  Hashes.with_ctxt ~git (fun hashes ->
      if create then
        if git && not (Sys.file_exists ".git") then (
          Git.call [ "init" ];
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
              let keep_readme = Sys.file_exists "README.md" in
              if not keep_readme then Misc.call [| "touch"; "README.md" |];
              Git.call [ "add"; "README.md" ];
              Git.call [ "commit"; "-m"; "Initial commit" ];
              if not keep_readme then Misc.call [| "rm"; "-f"; "README.md" |]
        );

      write_file hashes "dune-project" (Dune.template_dune_project p);

      List.iter
        (fun package ->
           match package.kind with
           | Virtual -> ()
           | _ ->
               ( match package.p_gen_version with
                 | None -> ()
                 | Some file ->
                     (* TODO : we should put info in this file *)
                     write_file hashes (package.dir // file)
                       (Printf.sprintf "let version = \"%s\"\n"
                          (Misc.p_version package)) );
               ( match Odoc.template_src_index_mld package with
                 | None -> ()
                 | Some content ->
                     write_file hashes (package.dir // "index.mld") content );

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
        (fun file ~create ~skips ~content ~record ~skip ->
           write_file hashes file ~create ~skips ~record ~skip content)
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

      let skip =
        not (upgrade || changed || not (Sys.file_exists "drom.toml"))
      in
      let content = Project.to_string p in
      write_file ~skip ~immediate:upgrade hashes "drom.toml" content;

      (* Save the "hash of all files", i.e. the hash of the drom.toml
         file that was used to generate all other files, to be able to
         detect need for update. We use '.' for the associated name,
         because it must be an existent file, otherwise `Hashes.save`
         will discard it. *)
      Hashes.update hashes "." (Hashes.digest_file "drom.toml"));
  ()
