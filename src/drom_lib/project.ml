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
  { package = dummy_package;
    packages = [];
    skeleton = None;
    edition = Globals.current_ocaml_edition;
    min_edition = Globals.current_ocaml_edition;
    github_organization = None;
    homepage = None;
    license = License.key_LGPL2;
    copyright = None;
    bug_reports = None;
    dev_repo = None;
    doc_gen = None;
    doc_api = None;
    generators = [ "ocamllex"; "ocamlyacc" ];
    skip = [];
    version = "0.1.0";
    authors = [];
    synopsis = "dummy_project.synopsis ";
    description = "dummy_project.description";
    dependencies = [];
    tools = [];
    mode = Binary;
    pack_modules = true;
    archive = None;
    sphinx_target = None;
    odoc_target = None;
    windows_ci = true;
    profiles = StringMap.empty;
    skip_dirs = [];
    fields = StringMap.empty;
    profile = None;
    file = None ;
    share_dirs = [ "share" ] ;
  }

and dummy_package =
  { name = "dummy_package";
    dir = "dummy_package.dir";
    project = dummy_project;
    p_file = None;
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
    p_gen_version = None;
    p_fields = StringMap.empty;
    p_skeleton = None;
    p_generators = None
  }

let create_package ~name ~dir ~kind = { dummy_package with name; dir; kind }

let kind_encoding =
  EzToml.enum_encoding
    ~to_string:(function
      | Virtual -> "virtual"
      | Library -> "library"
      | Program -> "program")
    ~of_string:(fun ~key:_ s ->
      match s with
      | "lib"
      | "library" ->
        Library
      | "program"
      | "executable"
      | "exe" ->
        Program
      | "meta"
      | "virtual" ->
        Virtual
      | kind ->
        Error.raise {|unknown kind %S (should be "library" or "program")|} kind)

let mode_encoding =
  EzToml.enum_encoding
    ~to_string:(function
      | Binary -> "binary"
      | Javascript -> "javascript")
    ~of_string:(fun ~key:_ s ->
      match s with
      | "bin"
      | "binary" ->
        Binary
      | "js"
      | "javascript"
      | "jsoo" ->
        Javascript
      | mode ->
        Error.raise {|unknown mode %S (should be "binary" or "javascript")|}
          mode)

let string_of_versions versions =
  String.concat " "
    (List.map
       (function
         | Version -> "version"
         | NoVersion -> ""
         | Semantic (major, minor, fix) ->
           Printf.sprintf "%d.%d.%d" major minor fix
         | Lt version -> Printf.sprintf "<%s" version
         | Le version -> Printf.sprintf "<=%s" version
         | Eq version -> Printf.sprintf "=%s" version
         | Ge version -> Printf.sprintf ">=%s" version
         | Gt version -> Printf.sprintf ">%s" version)
       versions)

let versions_of_string versions =
  List.map
    (fun version ->
      match Misc.semantic_version version with
      | Some (major, minor, fix) -> Semantic (major, minor, fix)
      | None -> (
        if version = "" then
          NoVersion
        else if version = "version" then
          Version
        else
          let len = String.length version in
          match version.[0] with
          | '=' -> Eq (String.sub version 1 (len - 1))
          | '<' ->
            if len > 1 && version.[1] = '=' then
              Le (String.sub version 2 (len - 2))
            else
              Lt (String.sub version 1 (len - 1))
          | '>' ->
            if len > 1 && version.[1] = '=' then
              Ge (String.sub version 2 (len - 2))
            else
              Gt (String.sub version 1 (len - 1))
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
          if d.deptest then
            EzToml.put [ "for-test" ] (TBool true) table
          else
            table
        in
        let table =
          if d.depdoc then
            EzToml.put [ "for-doc" ] (TBool true) table
          else
            table
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

let fields_encoding = stringMap_encoding EzToml.string_encoding

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
  |> EzToml.put_string_option [ "pack" ] pk.p_pack
  |> EzToml.put_encoding kind_encoding [ "kind" ] pk.kind
  |> EzToml.put_string_list_option [ "authors" ] pk.p_authors
  |> EzToml.put_encoding dependencies_encoding [ "dependencies" ]
       pk.p_dependencies
  |> EzToml.put_encoding dependencies_encoding [ "tools" ] pk.p_tools
  |> EzToml.put_string_option [ "gen-version" ] pk.p_gen_version
  |> EzToml.put_string_option [ "skeleton" ] pk.p_skeleton
  |> EzToml.put_encoding fields_encoding [ "fields" ] pk.p_fields
  |> EzToml.put_string_list_option [ "generators" ] pk.p_generators
  (* default to project ones *)
  |> EzToml.put_string_option [ "version" ] pk.p_version
  |> EzToml.put_bool_option [ "pack-modules" ] pk.p_pack_modules
  |> EzToml.put_encoding_option mode_encoding [ "mode" ] pk.p_mode
  |> EzToml.put_string_option [ "synopsis" ] pk.p_synopsis
  |> EzToml.put_string_option [ "description" ] pk.p_description

let find_package ?default name =
  let defaults =
    match default with
    | None -> []
    | Some p -> p.packages
  in
  let rec iter defaults =
    match defaults with
    | [] -> { dummy_package with name; dir = "src" // name }
    | package :: defaults ->
      if package.name = name then
        package
      else
        iter defaults
  in
  iter defaults

let package_of_toml ?default table =
  let dir = EzToml.get_string_option table [ "dir" ] in
  let table, p_file =
    match dir with
    | None -> (table, None)
    | Some dir ->
      let filename = dir // "package.toml" in
      if Sys.file_exists filename then
        let package_table =
          match EzToml.from_file filename with
          | `Ok table -> table
          | `Error (s, loc) ->
            Error.raise "Could not parse %S: %s at %s" filename s
              (EzToml.string_of_location loc)
        in
        let table =
          TomlTypes.Table.union (fun _key _ v -> Some v) package_table table
        in
        (table, Some filename)
      else
        (table, None)
  in
  let name = EzToml.get_string table [ "name" ] in
  let default = find_package ?default name in
  let dir = Misc.option_value dir ~default:default.dir in
  let kind =
    EzToml.get_encoding_default kind_encoding table [ "kind" ] default.kind
  in
  let project = dummy_project in
  let p_pack =
    EzToml.get_string_option table [ "pack" ] ?default:default.p_pack
  in
  let p_version =
    EzToml.get_string_option table [ "version" ] ?default:default.p_version
  in
  let p_authors =
    EzToml.get_string_list_option table [ "authors" ] ?default:default.p_authors
  in
  let p_synopsis =
    EzToml.get_string_option table [ "synopsis" ] ?default:default.p_synopsis
  in
  let p_description =
    EzToml.get_string_option table [ "description" ]
      ?default:default.p_description
  in
  let p_pack_modules =
    EzToml.get_bool_option table [ "pack-modules" ]
      ?default:default.p_pack_modules
  in
  let p_mode =
    EzToml.get_encoding_option mode_encoding table [ "mode" ]
      ?default:default.p_mode
  in
  let p_dependencies =
    EzToml.get_encoding_default dependencies_encoding table [ "dependencies" ]
      default.p_dependencies
  in
  let p_tools =
    EzToml.get_encoding_default dependencies_encoding table [ "tools" ]
      default.p_tools
  in
  let p_gen_version =
    EzToml.get_string_option table [ "gen-version" ]
      ?default:default.p_gen_version
  in
  let p_skeleton =
    EzToml.get_string_option table [ "skeleton" ] ?default:default.p_skeleton
  in
  let p_generators =
    EzToml.get_string_list_option table [ "generators" ]
      ?default:default.p_generators
  in
  let p_fields =
    EzToml.get_encoding_default fields_encoding table [ "fields" ]
      StringMap.empty
  in
  let p_fields =
    StringMap.union (fun _k a1 _a2 -> Some a1) p_fields default.p_fields
  in
  { name;
    dir;
    project;
    p_pack;
    p_file;
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
    p_fields;
    p_skeleton;
    p_generators
  }

let to_files p =
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
    |> maybe_package_key "odoc-target" p.odoc_target
    |> maybe_package_key "build-profile" p.profile
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
    |> EzToml.put_string_list [ "project"; "generators" ] p.generators
    |> EzToml.put [ "project"; "skip-dirs" ] (TArray (NodeString p.skip_dirs))
    |> EzToml.put [ "project"; "share-dirs" ] (TArray (NodeString p.share_dirs))
    |> EzToml.put_encoding
         (stringMap_encoding profile_encoding)
         [ "profile" ] p.profiles
    |> EzToml.put_encoding fields_encoding [ "fields" ] p.fields
    |> EzToml.to_string
  in

  let files = ref [] in
  let packages =
    List.map
      (fun package ->
        let toml = toml_of_package package in
        files :=
          (package.dir // "package.toml", EzToml.to_string toml) :: !files;
        EzToml.empty |> EzToml.put_string [ "dir" ] package.dir)
      p.packages
  in
  let packages =
    EzToml.empty
    |> EzToml.put [ "package" ] (TArray (NodeTable packages))
    |> EzToml.to_string
  in

  let content =
    Printf.sprintf "%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n" version package
      optionals package2 drom dependencies tools package3 packages
  in
  ("drom.toml", content) :: !files

let project_of_toml ?file ?default table =
  ( match EzToml.get_string_option table [ "project"; "drom-version" ] with
  | None -> ()
  | Some version -> (
    match VersionCompare.compare version Version.version with
    | 1 ->
      Error.raise
        "You must update `drom` to version %s to work with this project."
        version
    | _ -> () ) );

  let project_key, project_packages =
    match EzToml.get table [ "package" ] with
    | exception _ -> ("project", [])
    | TTable _ -> ("package", [])
    | TArray (NodeTable tables) ->
      let project_key = "project" in
      let packages = List.map (package_of_toml ?default) tables in
      (project_key, packages)
    | TArray NodeEmpty -> ("project", [])
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
          { dummy_project with
            synopsis = Globals.default_synopsis ~name;
            description = Globals.default_description ~name
          }
      in
      (name, default)
    with Not_found -> (
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
  let mode =
    EzToml.get_encoding_default mode_encoding table [ project_key; "mode" ]
      d.mode
  in
  let dependencies =
    EzToml.get_encoding_default dependencies_encoding table [ "dependencies" ]
      d.dependencies
  in
  let tools =
    EzToml.get_encoding_default dependencies_encoding table [ "tools" ] d.tools
  in
  let synopsis =
    EzToml.get_string_default table [ project_key; "synopsis" ] d.synopsis
  in
  let description =
    EzToml.get_string_default table [ project_key; "description" ] d.description
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
      EzToml.get_string_option table [ "drom"; "skip" ]
        ~default:(String.concat " " d.skip)
    with
    | None -> []
    | Some s -> EzString.split s ' '
  in
  let pack_modules =
    match EzToml.get_bool_option table [ project_key; "pack-modules" ] with
    | Some v -> v
    | None -> (
      match
        EzToml.get_bool_option table [ project_key; "wrapped" ]
          ~default:d.pack_modules
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

  let windows_ci =
    EzToml.get_bool_default table [ project_key; "windows-ci" ] d.windows_ci
  in
  let generators =
    EzToml.get_string_list_default table
      [ project_key; "generators" ]
      d.generators
  in
  let package, packages =
    let rec iter list =
      match list with
      | [] ->
        let p = find_package ?default name in
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
            depdoc = false
          } )
        :: package.p_dependencies;
      package.p_gen_version <- None;
      let lib_name = Misc.package_lib package in
      let lib =
        { dummy_package with
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
      (stringMap_encoding profile_encoding)
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
    EzToml.get_encoding_default fields_encoding table [ project_key; "fields" ]
      StringMap.empty
  in
  let fields = StringMap.union (fun _k a1 _a2 -> Some a1) fields d.fields in

  let project =
    { package;
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
      generators;
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
      odoc_target;
      windows_ci;
      packages;
      profiles;
      skip_dirs;
      share_dirs ;
      profile;
      fields
    }
  in
  package.project <- project;
  List.iter (fun p -> p.project <- project) packages;
  project

let of_string ~msg ?default content =
  if !Globals.verbosity > 1 then
    Printf.eprintf "Loading project from:\n<<<<\n%s\n>>>>>\n%!" content ;
  let table =
    match EzToml.from_string content with
    | `Ok table -> table
    | `Error (s, loc) ->
      Error.raise "Could not parse: %s at %s" msg s
        (EzToml.string_of_location loc)
  in
  project_of_toml ?default table

let project_of_filename ?default file =
  let table =
    match EzToml.from_file file with
    | `Ok table -> table
    | `Error (s, loc) ->
      Error.raise "Could not parse %S: %s at %s" file s
        (EzToml.string_of_location loc)
  in
  project_of_toml ~file ?default table

let find () =
  Globals.find_ancestor_file Globals.drom_file
    (fun ~dir ~path ->
       Unix.chdir dir;
       if Misc.verbose 1 then
         Printf.eprintf "drom: Entering directory '%s'\n%!" (Sys.getcwd ());
       ( project_of_filename Globals.drom_file, path )
    )

let get () =
  match find () with
  | None ->
    Error.raise
      "No project detected. Maybe you want to use 'drom project --new PROJECT' \
       instead"
  | Some (p, inferred_dir) -> (p, inferred_dir)

let read = project_of_filename

let package_of_string ~msg content =
  let table =
    match EzToml.from_string content with
    | `Ok table -> table
    | `Error (s, loc) ->
      Error.raise "Could not parse: %s at %s" msg s
        (EzToml.string_of_location loc)
  in
  package_of_toml table

let string_of_package package = EzToml.to_string (toml_of_package package)
