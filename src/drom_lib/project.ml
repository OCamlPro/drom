(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open EzToml.TYPES
open Types
open EzCompat
open Ez_file.V1
open EzFile.OP

let profile_encoding =
  EzToml.encoding
    ~to_toml:(fun prof ->
      let table = ref EzToml.empty in
      StringMap.iter
        (fun name s ->
          table := EzToml.put [ name ^ "-flags" ] (TString s) !table )
        prof.flags;
      TTable !table )
    ~of_toml:(fun ~key v ->
      let table = EzToml.expect_table ~key ~name:"profile" v in
      let flags = ref StringMap.empty in
      EzToml.iter
        (fun k v ->
          let key = key @ [ k ] in
          match Misc.EzString.chop_suffix k ~suffix:"-flags" with
          | None ->
            Printf.eprintf "Warning: discarding profile field %S\n%!"
              (EzToml.key2str key)
          | Some tool ->
            flags := StringMap.add tool (EzToml.expect_string ~key v) !flags )
        table;
      { flags = !flags } )

let find_author config =
  match config.config_author with
  | Some author -> author
  | None ->
    let user =
      try Sys.getenv "DROM_USER" with
      | Not_found -> (
        try Sys.getenv "GIT_AUTHOR_NAME" with
        | Not_found -> (
          try Sys.getenv "GIT_COMMITTER_NAME" with
          | Not_found -> (
            try Git.user () with
            | Not_found -> (
              try Sys.getenv "USER" with
              | Not_found -> (
                try Sys.getenv "USERNAME" with
                | Not_found -> (
                  try Sys.getenv "NAME" with
                  | Not_found ->
                    Error.raise
                      "Cannot determine user name. Hint: try to set DROM_USER."
                  ) ) ) ) ) )
    in
    let email =
      try Sys.getenv "DROM_EMAIL" with
      | Not_found -> (
        try Sys.getenv "GIT_AUTHOR_EMAIL" with
        | Not_found -> (
          try Sys.getenv "GIT_COMMITTER_EMAIL" with
          | Not_found -> (
            try Git.email () with
            | Not_found ->
              Error.raise
                "Cannot determine user email. Hint: try to set DROM_EMAIL." ) )
        )
    in
    Printf.sprintf "%s <%s>" user email

let to_files share p =
  let version =
    EzToml.empty
    |> EzToml.put_string [ "project"; "drom-version" ] p.project_drom_version
    |> EzToml.put_string_option [ "project"; "share-repo" ]
      p.project_share_repo
    |> EzToml.put_string_option [ "project"; "share-version" ]
      p.project_share_version
  in
  let version =
    if VersionCompare.compare share.drom_version "0.9.2~dev2" > 0 then begin
      version |> EzToml.put_bool [ "project"; "create-project" ]
      p.project_create
    end else
      version
  in
  let version = EzToml.to_string version in
  let package =
    EzToml.empty
    |> EzToml.put_string [ "project"; "name" ] p.package.name
    |> EzToml.put_string_option [ "project"; "skeleton" ] p.skeleton
    |> EzToml.put_string [ "project"; "version" ] p.version
    |> EzToml.put_string [ "project"; "edition" ] p.edition
    |> EzToml.put_string [ "project"; "min-edition" ] p.min_edition
    |> EzToml.put_string [ "project"; "synopsis" ] p.synopsis
    |> EzToml.put_string [ "project"; "license" ] p.license
    (*    |> EzToml.put_string [ "project" ; "dir" ] p.package.dir *)
    |> EzToml.put [ "project"; "authors" ] (TArray (NodeString p.authors))
    |> EzToml.put_string_list [ "project"; "ci-systems" ] p.ci_systems
  in
  let maybe_package_key key v (table, optionals) =
    match v with
    | None -> (table, key :: optionals)
    | Some v -> (EzToml.put_string [ "project"; key ] v table, optionals)
  in
  let package, optionals =
    (package, [])
    |> maybe_package_key "github-organization" p.github_organization
    |> maybe_package_key "homepage" p.homepage
    |> maybe_package_key "doc-gen" p.doc_gen
    |> maybe_package_key "doc-api" p.doc_api
    |> maybe_package_key "bug-reports" p.bug_reports
    |> maybe_package_key "dev-repo" p.dev_repo
    |> maybe_package_key "copyright" p.copyright
    |> maybe_package_key "archive" p.archive
    |> maybe_package_key "sphinx-target" p.sphinx_target
    |> maybe_package_key "odoc-target" p.odoc_target
  in
  let package2 =
    EzToml.empty
    |> EzToml.put_string [ "project"; "description" ] p.description
    |> EzToml.to_string
  in
  let drom =
    EzToml.empty
    |> EzToml.put_string_list [ "project"; "skip" ] p.skip
    |> EzToml.to_string
  in
  let package = EzToml.to_string package in
  let optionals =
    match optionals with
    | [] -> ""
    | optionals ->
      Printf.sprintf "# keys that you could also define:\n# %s\n"
        (String.concat "\n# "
           (List.map
              (fun s -> Printf.sprintf {|%s = "...%s..."|} s s)
              optionals ) )
  in
  let dependencies =
    match p.dependencies with
    | [] -> "[dependencies]\n"
    | _ ->
      EzToml.empty
      |> EzToml.put_encoding Package.dependencies_encoding [ "dependencies" ]
           p.dependencies
      |> EzToml.to_string
  in
  let dependencies =
    "# project-wide library dependencies (not for package-specific deps)\n"
    ^ dependencies
  in
  let tools =
    match p.tools with
    | [] -> "[tools]\n"
    | _ ->
      EzToml.empty
      |> EzToml.put_encoding Package.dependencies_encoding [ "tools" ] p.tools
      |> EzToml.to_string
  in
  let tools =
    "# project-wide tools dependencies (not for package-specific deps)\n"
    ^ tools
  in
  let package3 =
    EzToml.CONST.(
      s_ ~section:"project"
        [ option "skip-dirs"
            ~comment:[ "dirs to skip while scanning for dune files" ]
            (string_list p.skip_dirs);
          option "share-dirs"
            ~comment:[ "dirs to scan for share/ folders (with package names)" ]
            (string_list p.share_dirs);
          option "build-profile"
            ~comment:[ "build profile to use by default" ]
            (string_option p.profile);
          option "profile"
            ~comment:
              [ "Profile options for this project";
                {|    [profile]|};
                {|    dev = { ocaml-flags = "-w +a-4-40-41-42-44" }|};
                {|    release = { ocaml-flags = "-w -a" }|}
              ]
            (encoding (EzToml.ENCODING.stringMap profile_encoding) p.profiles);
          option "fields"
            ~comment:[
              "project-wide fields (depends on project skeleton)";
              " examples:";
              {|  docker-alpine-image = "ocamlpro/ocaml:4.13"|};
              {|  dune-lang = "2.1"|};
              {|  readme-trailer = "..."|};
              {|  dot-gitignore-trailer = "..."|};
            ]
            (encoding Package.fields_encoding p.fields)
        ] )
  in

  let files = ref [] in
  let packages =
    List.map
      (fun package ->
        let toml = Package.to_string package in
        files := (package.dir // "package.toml", toml) :: !files;
        (package.dir, EzToml.empty |> EzToml.put_string [ "dir" ] package.dir)
        )
      p.packages
  in
  let packages =
    String.concat "\n"
      (List.map
         (fun (dir, package) ->
           let s =
             EzToml.empty
             |> EzToml.put [ "package" ] (TArray (NodeTable [ package ]))
             |> EzToml.to_string
           in
           Printf.sprintf "%s# edit '%s' for package-specific options\n" s
             (dir // "package.toml") )
         packages )
  in

  let content =
    Printf.sprintf "%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n" version package
      optionals package2 drom dependencies tools package3 packages
  in
  ("drom.toml", content) :: !files

let project_of_toml ?file ?default table =
  let project_drom_version =
    match EzToml.get_string_option table [ "project"; "drom-version" ] with
    | None ->
      (* Using current version by default. *)
      Version.version
    | Some version ->
        match VersionCompare.compare version Version.version with
        | 1 ->
            Error.raise
              "You must update `drom` to version %s to work with this project."
              version
        | _ -> version
  in

  let project_key = "project" in
  let project_packages =
    match EzToml.get table [ "package" ] with
    | exception _ -> []
    | TTable _ -> []
    | TArray (NodeTable tables) -> List.map (Package.of_toml ?default) tables
    | TArray NodeEmpty -> []
    | TArray _ -> Error.raise "Wrong type for field 'package'"
    | _ -> Error.raise "Unparsable field 'package'"
  in

  let name, d =
    try
      let name = EzToml.get_string table [ project_key; "name" ] in
      let default =
        match default with
        | Some default -> default
        | None ->
            { Globals.dummy_project with
              synopsis = Globals.default_synopsis ~name;
              description = Globals.default_description ~name
            }
      in
      (name, default)
    with
    | Not_found -> (
        match default with
        | None -> Error.raise "Missing project field 'name'"
        | Some default -> (default.package.name, default) )
  in
  let authors =
    match
      EzToml.get_string_list_option ~default:d.authors table
        [ project_key; "authors" ]
    with
    | Some authors -> authors
    | None -> []
  in
  begin
    match authors with
    | [] -> Error.raise "No field 'authors' in drom.toml"
    | _ -> ()
  end;
  let version =
    EzToml.get_string_default table [ project_key; "version" ] d.version
  in
  let edition =
    EzToml.get_string_option ~default:d.edition table [ project_key; "edition" ]
  in
  let min_edition =
    EzToml.get_string_option ~default:d.min_edition table
      [ project_key; "min-edition" ]
  in
  let edition, min_edition =
    let default_version = Globals.current_ocaml_edition in
    match (edition, min_edition) with
    | None, None -> (default_version, default_version)
    | None, Some edition
    | Some edition, None ->
        (edition, edition)
    | Some edition, Some min_edition -> (
        match VersionCompare.compare min_edition edition with
        | 1 -> Error.raise "min-edition is greater than edition in drom.toml"
        | _ -> (edition, min_edition) )
  in
  let dependencies =
    EzToml.get_encoding_default Package.dependencies_encoding table
      [ "dependencies" ] d.dependencies
  in
  let tools =
    EzToml.get_encoding_default Package.dependencies_encoding table [ "tools" ]
      d.tools
  in
  let synopsis =
    EzToml.get_string_default table [ project_key; "synopsis" ] d.synopsis
  in
  let description =
    EzToml.get_string_default table [ project_key; "description" ] d.description
  in
  let project_share_repo =
    EzToml.get_string_option table [ project_key; "share-repo" ]
  in
  let project_share_version =
    EzToml.get_string_option table [ project_key; "share-version" ]
  in

  begin
    match project_share_repo, project_share_version with
    | None, None -> () (* old format 0.8.0 *)
    | Some _, Some _ -> () (* ok *)
    | _ ->
        Error.raise
          "Invalid drom.toml: both 'share-repo' and 'share-version' must be specified."
  end;

  let project_create =
    match
      EzToml.get_bool_option table [ project_key; "create-project" ]
        ~default:false
    with
    | Some v -> v
    | None -> false
  in

  let skeleton =
    EzToml.get_string_option table
      [ project_key; "skeleton" ]
      ?default:d.skeleton
  in
  let github_organization =
    EzToml.get_string_option table
      [ project_key; "github-organization" ]
      ?default:d.github_organization
  in
  let doc_api =
    EzToml.get_string_option table [ project_key; "doc-api" ] ?default:d.doc_api
  in
  let doc_gen =
    EzToml.get_string_option table [ project_key; "doc-gen" ] ?default:d.doc_gen
  in
  let homepage =
    EzToml.get_string_option table
      [ project_key; "homepage" ]
      ?default:d.homepage
  in
  let bug_reports =
    EzToml.get_string_option table
      [ project_key; "bug-reports" ]
      ?default:d.bug_reports
  in
  let dev_repo =
    EzToml.get_string_option table
      [ project_key; "dev-repo" ]
      ?default:d.dev_repo
  in
  let license =
    EzToml.get_string_default table [ project_key; "license" ] d.license
  in
  let copyright =
    EzToml.get_string_option table
      [ project_key; "copyright" ]
      ?default:d.copyright
  in
  let archive =
    EzToml.get_string_option table [ project_key; "archive" ] ?default:d.archive
  in
  let skip =
    match
      EzToml.get_encoding_option Package.skip_encoding table
        [ "project"; "skip" ]
    with
    | Some list -> list
    | None -> (
        match
          EzToml.get_string_option table [ "drom"; "skip" ]
            ~default:(String.concat " " d.skip)
        with
        | None -> []
        | Some s -> EzString.split s ' ' )
  in
  let _pack_modules =
    (* obsolete *)
    match EzToml.get_bool_option table [ project_key; "pack-modules" ] with
    | Some v -> v
    | None -> (
        match
          EzToml.get_bool_option table [ project_key; "wrapped" ] ~default:true
        with
        | Some v -> v
        | None -> true )
  in
  let sphinx_target =
    EzToml.get_string_option table
      [ project_key; "sphinx-target" ]
      ?default:d.sphinx_target
  in
  let odoc_target =
    EzToml.get_string_option table
      [ project_key; "odoc-target" ]
      ?default:d.odoc_target
  in
  let profile =
    EzToml.get_string_option table
      [ project_key; "build-profile" ]
      ?default:d.profile
  in

  let _generators =
    (* obsolete *)
    EzToml.get_string_list_default table [ project_key; "generators" ] []
  in
  let ci_systems =
    EzToml.get_string_list_default table
      [ project_key; "ci-systems" ]
      (let windows_ci =
         EzToml.get_bool_default table [ project_key; "windows-ci" ] true
       in
       if windows_ci then
         Globals.default_ci_systems
       else
         List.filter (fun s -> s <> "windows-latest") Globals.default_ci_systems
      )
  in
  let package, packages =
    let rec iter list =
      match list with
      | [] ->
          let p = Package.find ?default name in
          (p, p :: project_packages)
      | p :: tail ->
          if p.name = name then
            (p, project_packages)
          else
            iter tail
    in
    iter project_packages
  in

  let packages =
    match EzToml.get_string_option table [ project_key; "kind" ] with
    | Some "both" ->
        package.dir <- "main";
        package.kind <- Program;
        package.p_dependencies <-
          ( Misc.package_lib package,
            { depname = None;
              depversions = [ Version ];
              deptest = false;
              depdoc = false;
              depopt = false;
              dep_pin = None;
            } )
          :: package.p_dependencies;
        package.p_gen_version <- None;
        let lib_name = Misc.package_lib package in
        let lib =
          { Globals.dummy_package with
            name = lib_name;
            dir = "src" // lib_name;
            kind = Library
          }
        in
        packages @ [ lib ]
    | Some _
    | None ->
        packages
  in

  let profiles =
    EzToml.get_encoding_default
      (EzToml.ENCODING.stringMap profile_encoding)
      table [ "profile" ] d.profiles
  in
  let skip_dirs =
    EzToml.get_string_list_default table
      [ project_key; "skip-dirs" ]
      d.skip_dirs
  in
  let share_dirs =
    EzToml.get_string_list_default table
      [ project_key; "share-dirs" ]
      d.share_dirs
  in
  let fields =
    EzToml.get_encoding_default Package.fields_encoding table
      [ project_key; "fields" ] StringMap.empty
  in
  let p_fields =
    EzToml.get_encoding_default Package.fields_encoding table [ "fields" ]
      StringMap.empty
  in
  let fields = StringMap.union (fun _k a1 _a2 -> Some a1) fields d.fields in
  let fields = StringMap.union (fun _k a1 _a2 -> Some a1) fields p_fields in
  if Globals.verbose_subst then
    StringMap.iter
      (fun k _ -> Printf.eprintf "Project defined field %S\n%!" k)
      fields;

  let generators = ref StringSet.empty in
  List.iter
    (fun p ->
       match p.p_generators with
       | None -> ()
       | Some p_generators ->
           generators := StringSet.union !generators p_generators )
    packages;
  let generators = !generators in
  let menhir_version =
    List.fold_left
      (fun acc p ->
         match p.p_menhir with
         | None -> acc
         | Some { version; _ } ->
             match acc with
             | None ->
                 begin try Scanf.sscanf version "%d.%d" (fun _ _ -> ())
                   with Scanf.Scan_failure s ->
                     Error.raise "In package %s, invalid menhir version: %s (error: %s)"
                       p.name version s
                 end;
                 Some version
             | Some acc_version ->
                 if version <> acc_version then
                   Error.raise "In package %s, menhir version is different from other packages \
                                got %s when expecting %s" p.name version acc_version;
                 acc)
      None
      packages
  in
  let year = EzToml.get_int_default table [ project_key; "year" ] d.year in

  (* Check dune specification consistency :
     - dune version can only be specified at project's level. Defining it
       at package level has no practical meaning;
     - it can be given by [dune-lang] key in [fields] section for backward
       compatibility (this was introduced by the workaround in
       commit:f8f8f16);
     - it can be given by an explicit dependency in [tools], which is
       likely the better way.

     If no dune version is specified, drom uses the
     {!Globals.current_dune_version}. *)

  let after_0_9_2 = VersionCompare.compare project_drom_version "0.9.2" >= 0 in

  let dune_version =
    (* No dune dependencies in packages tools or dependencies. *)
    List.iter
      (fun (p : package) ->
         if List.mem_assoc "dune" p.p_dependencies then
           (* dune is in [p] dependencies which is silly: dune is a tool, not
              a library. *)
           Error.raise
             "Package %s has a dune dependency which has no meaning. Please \
              remove it"
             p.name;
         if List.mem_assoc "dune" p.p_tools then
           (* dune is in [p] tools which is bad project engineering design. *)
           Error.raise
             "Package %s gives dune as a tool dependency. Such dependency \
              should appears at project level, please move it in drom.toml."
             p.name )
      packages;
    (* Legacy dune lang version specification *)
    let legacy_dune_lang = StringMap.find_opt
        (if after_0_9_2 then "dune-lang" else "dune") p_fields in
    (* Checking that dune is not in project's dependencies, which has no more
       meaning than in packages *)
    if List.mem_assoc "dune" dependencies then
      Error.raise
        "Project has a dune dependency which has no meaning. Please remove it \
         or move it in [tools].";
    (* The valid way of overriding dune version. *)
    let dune_tool_spec = List.assoc_opt "dune"
        (if after_0_9_2 then tools else dependencies) in
    (* Normalizing *)
    let versions =
      match (legacy_dune_lang, dune_tool_spec) with
      | None, None -> [ Ge Globals.current_dune_version ]
      | Some legacy, None -> [ Ge legacy ]
      | None, Some dep -> dep.depversions
      | Some legacy, Some dep -> Ge legacy :: dep.depversions
    in
    (* The only interesting version is the infimum of possible versions
       for we need to know if we can use some dune feature or not. We
       assume that dune is backward compatible. If it's not, we must
       track all needed feature dependencies on dune version which is
       a bit overkill for now. To compute the infimum, we use the
       bottom "2.0" version which is the initial dune version used
       in drom so no support can be expected on lower versions. *)
    match
      Misc.infimum ~default:Globals.current_dune_version ~current:version
        ~bottom:"2.0" versions
    with
    | `unknown ->
        Error.raise
          "Can't determine the dune minimal version. Please consider less \
           restrictive dune specification."
    | `conflict (version, constraint_) ->
        Error.raise
          "dune version must be (>=%s), which contradicts the (%s) specification"
          version constraint_
    | `found version -> version
  in

  let project =
    { package;
      packages;
      project_drom_version ;
      project_share_repo;
      project_share_version;
      file;
      version;
      skeleton;
      edition;
      min_edition;
      authors;
      synopsis;
      description;
      dependencies;
      tools;
      github_organization;
      doc_gen;
      doc_api;
      homepage;
      license;
      bug_reports;
      dev_repo;
      copyright;
      skip;
      archive;
      sphinx_target;
      odoc_target;
      ci_systems;
      profiles;
      skip_dirs;
      share_dirs;
      profile;
      fields;
      generators;
      menhir_version;
      year;
      dune_version;
      project_create;
    }
  in
  package.project <- project;
  List.iter (fun p ->
    p.project <- project;
    if (
      VersionCompare.(project_drom_version >= "0.9.2") &&
      p.p_sites <> Sites.default &&
      not (List.mem_assoc "dune-site" p.p_dependencies)
    ) then
      (* Sites dynamic loading (available after 0.9.2) needs [dune-site]. *)
      p.p_dependencies <- ("dune-site", {
        depname = None;
        depversions = [ Ge "3.14.0" ];
        deptest = false;
        depdoc = false;
        depopt = false;
        dep_pin = None;
      }) :: p.p_dependencies
  ) packages;
  project

let of_string ~msg ?default content =
  if !Globals.verbosity > 1 then
    Printf.eprintf "Loading project from:\n<<<<\n%s\n>>>>>\n%!" content;
  let table =
    match EzToml.from_string content with
    | `Ok table -> table
    | `Error (s, loc) ->
      if !Globals.verbosity > 2 then begin
        let tmp = Filename.temp_file "project" "toml" in
        EzFile.write_file tmp content;
        Printf.eprintf "Wrong Toml Content written to %s\n%!" tmp
      end;
      Error.raise "Could not parse: %s at %s" msg s
        (EzToml.string_of_location loc)
  in
  project_of_toml ?default table

let of_file ?default file =
  let table =
    match EzToml.from_file file with
    | `Ok table -> table
    | `Error (s, loc) ->
      Error.raise "Could not parse %S: %s at %s" file s
        (EzToml.string_of_location loc)
  in
  project_of_toml ~file ?default table

let lookup () =
  Globals.find_ancestor_file Globals.drom_file (fun ~dir ~path -> (dir, path))

let find ?(display = true) () =
  match lookup () with
  | None -> None
  | Some (dir, path) ->
    Unix.chdir dir;
    if display && Globals.verbose 1 then
      Printf.eprintf "drom: Entering directory '%s'\n%!" (Sys.getcwd ());
    Some (of_file Globals.drom_file, path)

let get () =
  match find () with
  | None ->
    Error.raise
      "No project detected. Maybe you want to use 'drom project --new PROJECT' \
       instead"
  | Some (p, inferred_dir) -> (p, inferred_dir)
