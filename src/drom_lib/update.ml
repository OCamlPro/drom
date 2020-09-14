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
open EzCompat

let library_name p =
  match p.p_pack with
  | Some name -> String.uncapitalize_ascii name
  | None ->
      let s = Bytes.of_string p.name in
      for i = 1 to String.length p.name - 2 do
        let c = p.name.[i] in
        match c with 'a' .. 'z' | '0' .. '9' -> () | _ -> Bytes.set s i '_'
      done;
      Bytes.to_string s

let library_module p =
  match p.p_pack with
  | Some name -> name
  | None ->
      let s = Bytes.of_string p.name in
      Bytes.set s 0 (Char.uppercase p.name.[0]);
      for i = 1 to String.length p.name - 2 do
        let c = p.name.[i] in
        match c with 'a' .. 'z' | '0' .. '9' -> () | _ -> Bytes.set s i '_'
      done;
      Bytes.to_string s

let template_src_main_ml ~header_ml p =
  match p.kind with
  | Virtual -> assert false
  | Library ->
      Printf.sprintf
        {|%s
(* If you delete or rename this file, you should add '%s/main.ml' to the 'skip' field in "drom.toml" *)

let main () = Printf.printf "Hello world!\n%!"
|}
        header_ml p.dir
  | Program -> (
      match p.p_driver_only with
      | Some library_module ->
          Printf.sprintf {|%s
let () = %s ()
|} header_ml library_module
      | _ ->
          Printf.sprintf
            {|%s
(* If you rename this file, you should add '%s/main.ml' to the 'skip' field in "drom.toml" *)

let () = Printf.printf "Hello world!\n%!"
|}
            header_ml p.dir )

exception Skip

let update_files ?mode ?(upgrade = false) ?(git = false) ?(create = false)
    ?(promote_skip = false) p =
  let can_skip = ref [] in
  let not_skipped s =
    can_skip := s :: !can_skip;
    not (List.mem s p.skip)
  in
  let save_hashes = ref false in
  let hashes =
    if Sys.file_exists ".drom" then (
      let map = ref StringMap.empty in
      (* Printf.eprintf "Loading .drom\n%!"; *)
      Array.iter
        (fun line ->
          if line <> "" && line.[0] <> '#' then
            let digest, filename = EzString.cut_at line ' ' in
            let digest = Digest.from_hex digest in
            map := StringMap.add filename digest !map)
        (EzFile.read_lines ".drom");
      !map )
    else StringMap.empty
  in
  let hashes = ref hashes in
  let to_add = ref [] in
  let to_remove = ref [] in
  let skipped = ref [] in
  let write_file ?(record = true) filename content =
    let dirname = Filename.dirname filename in
    EzFile.make_dir ~p:true dirname;
    EzFile.write_file filename content;
    if record then (
      hashes := StringMap.add filename (Digest.string content) !hashes;
      save_hashes := true;
      to_add := filename :: !to_add )
  in
  let can_update ~filename content =
    let old_content = EzFile.read_file filename in
    if content = old_content then false
    else
      let hash = Digest.string old_content in
      try
        let former_hash = StringMap.find filename !hashes in
        let not_modified = former_hash = hash in
        if not not_modified then (
          skipped := filename :: !skipped;
          Printf.eprintf "Skipping modified file %s\n%!" filename );
        not_modified
      with Not_found ->
        skipped := filename :: !skipped;
        Printf.eprintf "Skipping existing file %s\n%!" filename;
        false
  in
  (*
  let remove_file filename =
    if Sys.file_exists filename then
      let old_content = EzFile.read_file filename in
      let hash = Digest.string old_content in
      try
        let former_hash = StringMap.find filename !hashes in
        if former_hash <> hash then
          Printf.eprintf "Keeping modified file %s\n%!" filename
        else begin
          hashes := StringMap.remove filename !hashes ;
          save_hashes := true ;
          to_remove := filename ::!to_remove
        end
      with Not_found -> ()
  in
*)
  let write_file ?(record = true) ?((* add to git *)
                                  create = false)
      ?((* only create, never update *)
      skip = false) ?((* force to skip *)
                    force = false) ?((* force to write *)
                                   skips = []) (* tests for skipping *)
                                                 filename content =
    try
      if skip then raise Skip;
      if force then (
        Printf.eprintf "Updating file %s\n%!" filename;
        write_file filename content )
      else if not_skipped filename && List.for_all not_skipped skips then
        if not record then write_file ~record:false filename content
        else if not (Sys.file_exists filename) then (
          Printf.eprintf "Creating file %s\n%!" filename;
          write_file filename content )
        else if create then raise Skip
        else if can_update ~filename content then (
          Printf.eprintf "Updating file %s\n%!" filename;
          write_file filename content )
        else raise Skip
      else raise Skip
    with Skip ->
      let filename = "_drom" // "skipped" // filename in
      EzFile.make_dir ~p:true (Filename.dirname filename);
      EzFile.write_file filename content
  in

  let config = Lazy.force Config.config in

  let changed = false in
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
    else (p, changed)
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
              { depversions; depname = None; deptest = false; depdoc = false }
            )
          in
          match mode with
          | Binary ->
              if List.mem dep deps then (EzList.remove dep deps, true)
              else (deps, changed)
          | Javascript ->
              if not (List.mem_assoc (fst dep) deps) then (dep :: deps, true)
              else (deps, changed)
        in
        let dependencies, changed = add_dep js_dep p.dependencies changed in
        let tools, changed = add_dep js_tool p.tools changed in
        let tools, changed = add_dep ppx_tool tools changed in
        ({ p with mode; dependencies; tools }, changed)
  in

  let body () =
    write_file "dune" (Dune.template_dune p);

    let header_ml = License.header_ml p in

    write_file "dune-project" (Dune.template_dune_project p);

    List.iter
      (fun package ->
        match package.kind with
        | Virtual -> ()
        | _ ->
            ( match package.p_gen_version with
            | None -> ()
            | Some file ->
                (* TODO : we should put info in this file *)
                write_file (package.dir // file)
                  (Printf.sprintf "let version = \"%s\"\n"
                     (Misc.p_version package)) );

            let file = package.dir // "main.ml" in
            write_file file (template_src_main_ml ~header_ml package);

            ( match Odoc.template_src_index_mld package with
            | None -> ()
            | Some content -> write_file (package.dir // "index.mld") content );

            let opam_filename = package.name ^ ".opam" in
            write_file opam_filename (Opam.opam_of_project Single package))
      p.packages;

    EzFile.make_dir ~p:true Globals.drom_dir;

    EzFile.write_file
      (Globals.drom_dir // "known-licences.txt")
      (License.known_licenses ());

    EzFile.write_file (Globals.drom_dir // "header.ml") (License.header_ml p);
    EzFile.write_file (Globals.drom_dir // "header.mll") (License.header_mll p);
    EzFile.write_file (Globals.drom_dir // "header.mly") (License.header_mly p);

    EzFile.write_file
      (Globals.drom_dir // "maximum-skip-field.txt")
      (Printf.sprintf "skip = \"%s\"\n" (String.concat " " !can_skip));

    (* Most of the files are created using Skeleton *)
    (let skeleton =
       match p.skeleton with
       | None -> Some Skel_default.skeleton
       | Some skeleton -> Skeleton.load skeleton
     in
     match skeleton with
     | None -> ()
     | Some skeleton ->
         Skeleton.write_files
           (fun file ~create ~skips ~content ~record ->
             write_file file ~create ~skips ~record content)
           p skeleton);

    let p, changed =
      if promote_skip && !skipped <> [] then (
        let skip = p.skip @ !skipped in
        Printf.eprintf "skip field promotion: %s\n%!"
          (String.concat " " !skipped);
        ({ p with skip }, true) )
      else (p, changed)
    in

    let skip = not (upgrade || changed || not (Sys.file_exists "drom.toml")) in
    write_file ~skip ~force:upgrade "drom.toml" (Project.toml_of_project p);

    if create then
      if git && not (Sys.file_exists ".git") then (
        Misc.call [| "git"; "init" |];
        match config.config_github_organization with
        | None -> ()
        | Some organization ->
            Misc.call
              [|
                "git";
                "remote";
                "add";
                "origin";
                Printf.sprintf "git@github.com:%s/%s" organization
                  p.package.name;
              |];
            Misc.call [| "git"; "add"; "README.md" |];
            Misc.call [| "git"; "commit"; "-m"; "Initial commit" |] )
  in

  let closer () =
    if !save_hashes then (
      let b = Buffer.create 1000 in
      Printf.bprintf b
        "# Keep this file in your GIT repo to help drom track generated files\n";
      StringMap.iter
        (fun filename hash ->
          Printf.bprintf b "%s %s\n" (Digest.to_hex hash) filename)
        !hashes;
      EzFile.write_file ".drom" (Buffer.contents b);
      if git && Sys.file_exists ".git" then (
        Misc.call (Array.of_list ("git" :: "add" :: ".drom" :: !to_add));
        match !to_remove with
        | [] -> ()
        | files -> Misc.call (Array.of_list ("git" :: "rm" :: files)) ) )
  in

  match body () with
  | () -> closer ()
  | exception exn ->
      let bt = Printexc.get_raw_backtrace () in
      Printf.eprintf "An error happened. Saving intermediate changes.\n%!";
      closer ();
      Printexc.raise_with_backtrace exn bt
