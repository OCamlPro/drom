(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open EzToml.TYPES
open Types
open EzCompat
open EzFile.OP

let rec dummy_project =
  {
    package = dummy_package;
    packages = [];
    skeleton = None;
    edition = "dummy_project.edition";
    min_edition = "dummy_project.min_edition";
    github_organization = None;
    homepage = None;
    license = "dummy_project.license";
    copyright = None;
    bug_reports = None;
    dev_repo = None;
    doc_gen = None;
    doc_api = None;
    skip = [];
    version = "dummy_project.version";
    authors = [ "dummy_project.authors" ];
    synopsis = "dummy_project.synopsis ";
    description = "dummy_project.description";
    dependencies = [];
    tools = [];
    mode = Binary;
    pack_modules = true;
    archive = None;
    sphinx_target = None;
    windows_ci = true;
    profiles = StringMap.empty;
    skip_dirs = [];
  }

and dummy_package =
  {
    name = "dummy_package";
    dir = "dummy_package.dir";
    project = dummy_project;
    p_pack = None;
    kind = Library;
    p_version = None;
    p_authors = None;
    p_synopsis = None;
    p_description = None;
    p_dependencies = [];
    p_tools = [];
    p_mode = None;
    p_pack_modules = None;
    p_gen_version = Some "version.ml";
    p_driver_only = None;
  }

let create_package ~name ~dir ~kind = { dummy_package with name; dir; kind }

let kind_encoding =
  EzToml.string_encoding
    ~to_string:(function
      | Virtual -> "virtual" | Library -> "library" | Program -> "program")
    ~of_string:(fun ~key:_ s ->
      match s with
      | "lib" | "library" -> Library
      | "program" | "executable" | "exe" -> Program
      | "meta" | "virtual" -> Virtual
      | kind ->
          Error.raise {|unknown kind %S (should be "library" or "program")|}
            kind)

let mode_encoding =
  EzToml.string_encoding
    ~to_string:(function Binary -> "binary" | Javascript -> "javascript")
    ~of_string:(fun ~key:_ s ->
      match s with
      | "bin" | "binary" -> Binary
      | "js" | "javascript" | "jsoo" -> Javascript
      | mode ->
          Error.raise {|unknown mode %S (should be "binary" or "javascript")|}
            mode)

let string_of_versions versions =
  String.concat " "
    (List.map
       (function
         | Version -> "version"
         | Semantic (major, minor, fix) ->
             Printf.sprintf "%d.%d.%d" major minor fix
         | Lt version -> Printf.sprintf "<%s" version
         | Le version -> Printf.sprintf "<=%s" version
         | Eq version -> Printf.sprintf "=%s" version
         | Ge version -> Printf.sprintf ">%s" version
         | Gt version -> Printf.sprintf ">=%s" version)
       versions)

let versions_of_string versions =
  List.map
    (fun version ->
      match Misc.semantic_version version with
      | Some (major, minor, fix) -> Semantic (major, minor, fix)
      | None -> (
          if version = "version" then Version
          else
            let len = String.length version in
            match version.[0] with
            | '=' -> Eq (String.sub version 1 (len - 1))
            | '<' ->
                if len > 1 && version.[1] = '=' then
                  Le (String.sub version 2 (len - 2))
                else Lt (String.sub version 1 (len - 1))
            | '>' ->
                if len > 1 && version.[1] = '=' then
                  Ge (String.sub version 2 (len - 2))
                else Gt (String.sub version 1 (len - 1))
            | _ -> Ge version ))
    (EzString.split_simplify versions ' ')

let dependency_encoding =
  EzToml.encoding
    ~to_toml:(fun d ->
      let version = TString (string_of_versions d.depversions) in
      match (d.depname, d.deptest, d.depdoc) with
      | None, false, false -> version
      | _ ->
          let table = EzToml.empty in
          let table = EzToml.put_string_option [ "libname" ] d.depname table in
          let table =
            match d.depversions with
            | [] -> table
            | _ -> EzToml.put [ "version" ] version table
          in
          let table =
            if d.deptest then EzToml.put [ "for-test" ] (TBool true) table
            else table
          in
          let table =
            if d.depdoc then EzToml.put [ "for-doc" ] (TBool true) table
            else table
          in
          TTable table)
    ~of_toml:(fun ~key v ->
      match v with
      | TString s ->
          let depversions = versions_of_string s in
          { depname = None; depversions; depdoc = false; deptest = false }
      | TTable table ->
          let depname = EzToml.get_string_option table [ "libname" ] in
          let depversions = EzToml.get_string_default table [ "version" ] "" in
          let depversions = versions_of_string depversions in
          let deptest = EzToml.get_bool_default table [ "for-test" ] false in
          let depdoc = EzToml.get_bool_default table [ "for-doc" ] false in
          { depname; depversions; depdoc; deptest }
      | _ -> Error.raise "Bad dependency version for %s" (EzToml.key2str key))

let dependencies_encoding =
  EzToml.encoding
    ~to_toml:(fun deps ->
      let table =
        List.fold_left
          (fun table (name, d) ->
            EzToml.put_encoding dependency_encoding [ name ] d table)
          EzToml.empty deps
      in
      TTable table)
    ~of_toml:(fun ~key v ->
      let deps = EzToml.expect_table ~key ~name:"dependency list" v in
      let dependencies = ref [] in
      Table.iter
        (fun name _version ->
          let name = Table.Key.to_string name in
          let d = EzToml.get_encoding dependency_encoding deps [ name ] in
          dependencies := (name, d) :: !dependencies)
        deps;
      !dependencies)

let stringMap_encoding enc =
  EzToml.encoding
    ~to_toml:(fun map ->
      let table = ref EzToml.empty in
      StringMap.iter
        (fun name s -> table := EzToml.put [ name ] (enc.to_toml s) !table)
        map;
      TTable !table)
    ~of_toml:(fun ~key v ->
      let table = EzToml.expect_table ~key ~name:"profile" v in
      let map = ref StringMap.empty in
      EzToml.iter
        (fun k v ->
          map := StringMap.add k (enc.of_toml ~key:(key @ [ k ]) v) !map)
        table;
      !map)

let profile_encoding =
  EzToml.encoding
    ~to_toml:(fun prof ->
      let table = ref EzToml.empty in
      StringMap.iter
        (fun name s ->
          table := EzToml.put [ name ^ "-flags" ] (TString s) !table)
        prof.flags;
      TTable !table)
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
              flags := StringMap.add tool (EzToml.expect_string ~key v) !flags)
        table;
      { flags = !flags })

let find_author config =
  match config.config_author with
  | Some author -> author
  | None ->
      let user =
        try Sys.getenv "DROM_USER"
        with Not_found -> (
          try Sys.getenv "GIT_AUTHOR_NAME"
          with Not_found -> (
            try Sys.getenv "GIT_COMMITTER_NAME"
            with Not_found -> (
              try Git.user ()
              with Not_found -> (
                try Sys.getenv "USER"
                with Not_found -> (
                  try Sys.getenv "USERNAME"
                  with Not_found -> (
                    try Sys.getenv "NAME"
                    with Not_found -> Error.raise "Cannot determine user name" ) ) ) ) ) )
      in
      let email =
        try Sys.getenv "DROM_EMAIL"
        with Not_found -> (
          try Sys.getenv "GIT_AUTHOR_EMAIL"
          with Not_found -> (
            try Sys.getenv "GIT_COMMITTER_EMAIL"
            with Not_found -> (
              try Git.email ()
              with Not_found -> Error.raise "Cannot determine user email" ) ) )
      in
      Printf.sprintf "%s <%s>" user email

let toml_of_package pk =
  EzToml.empty
  |> EzToml.put_string [ "name" ] pk.name
  |> EzToml.put_string [ "dir" ] pk.dir
  |> EzToml.put_string_option [ "pack" ] pk.p_pack
  |> EzToml.put_string_option [ "version" ] pk.p_version
  |> EzToml.put_encoding kind_encoding [ "kind" ] pk.kind
  |> EzToml.put_string_list_option [ "authors" ] pk.p_authors
  |> EzToml.put_string_option [ "synopsis" ] pk.p_synopsis
  |> EzToml.put_string_option [ "description" ] pk.p_description
  |> EzToml.put_encoding_option mode_encoding [ "mode" ] pk.p_mode
  |> EzToml.put_encoding dependencies_encoding [ "dependencies" ]
       pk.p_dependencies
  |> EzToml.put_encoding dependencies_encoding [ "tools" ] pk.p_tools
  |> EzToml.put_bool_option [ "pack-modules" ] pk.p_pack_modules
  |> EzToml.put_string_option [ "gen-version" ] pk.p_gen_version
  |> EzToml.put_string_option [ "driver-only" ] pk.p_driver_only

let package_of_toml table =
  let name = EzToml.get_string table [ "name" ] in
  let dir = EzToml.get_string table [ "dir" ] in
  let kind =
    EzToml.get_encoding_default kind_encoding table [ "kind" ] Library
  in
  let project = dummy_project in
  let p_pack = EzToml.get_string_option table [ "pack" ] in
  let p_version = EzToml.get_string_option table [ "version" ] in
  let p_authors = EzToml.get_string_list_option table [ "authors" ] in
  let p_synopsis = EzToml.get_string_option table [ "synopsis" ] in
  let p_description = EzToml.get_string_option table [ "description" ] in
  let p_pack_modules = EzToml.get_bool_option table [ "pack-modules" ] in
  let p_mode = EzToml.get_encoding_option mode_encoding table [ "mode" ] in
  let p_dependencies =
    EzToml.get_encoding_default dependencies_encoding table [ "dependencies" ]
      []
  in
  let p_tools =
    EzToml.get_encoding_default dependencies_encoding table [ "tools" ] []
  in
  let p_gen_version = EzToml.get_string_option table [ "gen-version" ] in
  let p_driver_only = EzToml.get_string_option table [ "driver-only" ] in
  {
    name;
    dir;
    project;
    p_pack;
    kind;
    p_version;
    p_authors;
    p_synopsis;
    p_description;
    p_dependencies;
    p_tools;
    p_mode;
    p_pack_modules;
    p_gen_version;
    p_driver_only;
  }

let toml_of_project p =
  let version =
    EzToml.empty
    |> EzToml.put_string [ "project"; "drom-version" ] Globals.min_drom_version
    |> EzToml.to_string
  in
  let package =
    EzToml.empty
    |> EzToml.put_string [ "project"; "name" ] p.package.name
    |> EzToml.put_string_option [ "project"; "skeleton" ] p.skeleton
    |> EzToml.put_string [ "project"; "version" ] p.version
    |> EzToml.put_string [ "project"; "edition" ] p.edition
    |> EzToml.put_string [ "project"; "min-edition" ] p.min_edition
    |> EzToml.put_encoding mode_encoding [ "project"; "mode" ] p.mode
    |> EzToml.put_string [ "project"; "synopsis" ] p.synopsis
    |> EzToml.put_string [ "project"; "license" ] p.license
    (*    |> EzToml.put_string [ "project" ; "dir" ] p.package.dir *)
    |> EzToml.put [ "project"; "authors" ] (TArray (NodeString p.authors))
    |> EzToml.put_bool [ "project"; "windows-ci" ] p.windows_ci
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
  in
  let package2 =
    EzToml.empty
    |> EzToml.put_string [ "project"; "description" ] p.description
    |> EzToml.to_string
  in
  let drom =
    EzToml.empty
    |> EzToml.put_string [ "drom"; "skip" ] (String.concat " " p.skip)
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
                optionals))
  in
  let dependencies =
    match p.dependencies with
    | [] -> "[dependencies]\n"
    | _ ->
        EzToml.empty
        |> EzToml.put_encoding dependencies_encoding [ "dependencies" ]
             p.dependencies
        |> EzToml.to_string
  in
  let tools =
    match p.tools with
    | [] -> "[tools]\n"
    | _ ->
        EzToml.empty
        |> EzToml.put_encoding dependencies_encoding [ "tools" ] p.tools
        |> EzToml.to_string
  in
  let package3 =
    EzToml.empty
    |> EzToml.put_bool [ "project"; "pack-modules" ] p.pack_modules
    |> EzToml.put_string_option [ "project"; "pack" ] p.package.p_pack
    |> EzToml.put [ "project"; "skip-dirs" ] (TArray (NodeString p.skip_dirs))
    |> EzToml.put_encoding
         (stringMap_encoding profile_encoding)
         [ "profile" ] p.profiles
    |> EzToml.to_string
  in

  let packages =
    EzToml.empty
    |> EzToml.put [ "package" ]
         (TArray (NodeTable (List.map toml_of_package p.packages)))
    |> EzToml.to_string
  in

  Printf.sprintf "%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n" version package
    optionals package2 drom dependencies tools package3 packages

let project_of_toml filename =
  (*  Printf.eprintf "Loading %s\n%!" filename ; *)
  let table =
    match EzToml.from_file filename with
    | `Ok table -> table
    | `Error _ -> Error.raise "Could not parse %S" filename
  in

  ( match EzToml.get_string_option table [ "project"; "drom-version" ] with
  | None -> ()
  | Some version -> (
      match VersionCompare.compare version Version.version with
      | 1 ->
          Error.raise
            "You must update `drom` to version %s to work with this project."
            version
      | _ -> () ) );

  let project_key, packages =
    match EzToml.get table [ "package" ] with
    | exception _ -> ("project", [])
    | TTable _ -> ("package", [])
    | TArray (NodeTable tables) ->
        let project_key = "project" in
        let packages = List.map package_of_toml tables in
        (project_key, packages)
    | TArray NodeEmpty -> ("project", [])
    | TArray _ -> Error.raise "Wrong type for field 'package'"
    | _ -> Error.raise "Unparsable field 'package'"
  in

  let name =
    try EzToml.get_string table [ project_key; "name" ]
    with Not_found -> Error.raise "Missing project field 'name'"
  in
  let version =
    EzToml.get_string_default table [ project_key; "version" ] "0.1.0"
  in
  let edition = EzToml.get_string_option table [ project_key; "edition" ] in
  let min_edition =
    EzToml.get_string_option table [ project_key; "min-edition" ]
  in
  let edition, min_edition =
    let default_version = Globals.current_ocaml_edition in
    match (edition, min_edition) with
    | None, None -> (default_version, default_version)
    | None, Some edition | Some edition, None -> (edition, edition)
    | Some edition, Some min_edition -> (
        match VersionCompare.compare min_edition edition with
        | 1 -> Error.raise "min-edition is greater than edition in drom.toml"
        | _ -> (edition, min_edition) )
  in
  let mode =
    EzToml.get_encoding_default mode_encoding table [ project_key; "mode" ]
      Binary
  in
  let authors =
    match EzToml.get_string_list_option table [ project_key; "authors" ] with
    | Some authors -> authors
    | None -> Error.raise "No field 'authors' in drom.toml"
  in
  let dependencies =
    EzToml.get_encoding_default dependencies_encoding table [ "dependencies" ]
      []
  in
  let tools =
    EzToml.get_encoding_default dependencies_encoding table [ "tools" ] []
  in
  let synopsis =
    EzToml.get_string_default table
      [ project_key; "synopsis" ]
      (Globals.default_synopsis ~name)
  in
  let description =
    EzToml.get_string_default table
      [ project_key; "description" ]
      (Globals.default_description ~name)
  in
  let skeleton = EzToml.get_string_option table [ project_key; "skeleton" ] in
  let github_organization =
    EzToml.get_string_option table [ project_key; "github-organization" ]
  in
  let doc_api = EzToml.get_string_option table [ project_key; "doc-api" ] in
  let doc_gen = EzToml.get_string_option table [ project_key; "doc-gen" ] in
  let homepage = EzToml.get_string_option table [ project_key; "homepage" ] in
  let bug_reports =
    EzToml.get_string_option table [ project_key; "bug-reports" ]
  in
  let dev_repo = EzToml.get_string_option table [ project_key; "dev-repo" ] in
  let license =
    EzToml.get_string_default table [ project_key; "license" ] License.LGPL2.key
  in
  let copyright = EzToml.get_string_option table [ project_key; "copyright" ] in
  let archive = EzToml.get_string_option table [ project_key; "archive" ] in
  let skip =
    match EzToml.get_string_option table [ "drom"; "skip" ] with
    | None -> []
    | Some s -> EzString.split s ' '
  in
  let pack_modules =
    match EzToml.get_bool_option table [ project_key; "pack-modules" ] with
    | Some v -> v
    | None -> (
        match EzToml.get_bool_option table [ project_key; "wrapped" ] with
        | Some v -> v
        | None -> true )
  in
  let sphinx_target =
    EzToml.get_string_option table [ project_key; "sphinx-target" ]
  in

  let p_pack = EzToml.get_string_option table [ project_key; "pack" ] in
  let dir = EzToml.get_string_option table [ project_key; "dir" ] in
  let windows_ci =
    EzToml.get_bool_default table [ project_key; "windows-ci" ] true
  in
  let package, packages =
    let rec iter list =
      match list with
      | [] ->
          let dir = match dir with None -> "src" | Some dir -> dir in
          let p = { dummy_package with name; dir; p_pack } in
          (p, p :: packages)
      | p :: tail ->
          if p.name = name then (
            ( match dir with
            | None -> ()
            | Some dir ->
                if dir <> p.dir then
                  Error.raise "'dir' field differs in project and %S" name );
            ( match (p_pack, p.p_pack) with
            | Some v1, Some v2 when v1 <> v2 ->
                Error.raise "'pack' field differs in project and %S" name
            | Some p_pack, None -> p.p_pack <- Some p_pack
            | _ -> () );
            (p, packages) )
          else iter tail
    in
    iter packages
  in

  let packages =
    match EzToml.get_string_option table [ project_key; "kind" ] with
    | Some "both" ->
        package.dir <- "main";
        package.kind <- Program;
        let driver_only =
          String.capitalize (Misc.package_lib package) ^ ".Main.main"
        in
        package.p_driver_only <- Some driver_only;
        package.p_dependencies <-
          ( Misc.package_lib package,
            {
              depname = None;
              depversions = [ Version ];
              deptest = false;
              depdoc = false;
            } )
          :: package.p_dependencies;
        package.p_gen_version <- None;
        let lib =
          {
            dummy_package with
            name = Misc.package_lib package;
            dir = "src";
            kind = Library;
          }
        in
        packages @ [ lib ]
    | Some _ | None -> packages
  in

  let profiles =
    EzToml.get_encoding_default
      (stringMap_encoding profile_encoding)
      table [ "profile" ] StringMap.empty
  in
  let skip_dirs =
    EzToml.get_string_list_default table [ project_key; "skip-dirs" ] []
  in

  let project =
    {
      package;
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
      mode;
      pack_modules;
      archive;
      sphinx_target;
      windows_ci;
      packages;
      profiles;
      skip_dirs;
    }
  in
  package.project <- project;
  List.iter (fun p -> p.project <- project) packages;
  project

let find_project () =
  let dir = Sys.getcwd () in
  let rec iter dir path =
    let drom_file = dir // "drom.toml" in
    if Sys.file_exists drom_file then (
      Unix.chdir dir;
      Some (project_of_toml drom_file, path) )
    else
      let updir = Filename.dirname dir in
      if updir <> dir then iter updir (Filename.basename dir // path) else None
  in
  iter dir ""
