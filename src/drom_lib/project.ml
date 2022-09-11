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
open Ez_file.V1
open EzFile.OP

let verbose_subst =
  try
    ignore (Sys.getenv "DROM_VERBOSE_SUBST");
    true
  with Not_found -> false

let rec dummy_project =
  { package = dummy_package;
    packages = [];
    skeleton = None;
    edition = Globals.current_ocaml_edition;
    min_edition = Globals.min_ocaml_edition;
    github_organization = None;
    homepage = None;
    license = License.key_LGPL2;
    copyright = None;
    bug_reports = None;
    dev_repo = None;
    doc_gen = None;
    doc_api = None;
    skip = [];
    version = "0.1.0";
    authors = [];
    synopsis = "dummy_project.synopsis ";
    description = "dummy_project.description";
    dependencies = [];
    tools = [];
    archive = None;
    sphinx_target = None;
    odoc_target = None;
    ci_systems = Misc.default_ci_systems;
    profiles = StringMap.empty;
    skip_dirs = [];
    fields = StringMap.empty;
    profile = None;
    file = None ;
    share_dirs = [ "share" ] ;
    year = (Misc.date ()).Unix.tm_year;
    generators = StringSet.empty;
    dune_version = Globals.current_dune_version;
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
    p_pack_modules = None;
    p_gen_version = None;
    p_fields = StringMap.empty;
    p_skeleton = None;
    p_generators = None;
    p_skip = None;
    p_optional = None ;
    p_preprocess = None ;
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

let skip_encoding =
  let to_toml list =
    match list with
    | [] -> TArray NodeEmpty
    | list -> TArray (NodeString list)
  in
  let of_toml ~key value =
    match value with
    | TArray NodeEmpty -> []
    | TArray (NodeString v) -> v
    | TString s -> EzString.split s ' '
    | _ -> EzToml.failwith "Wrong type for field %S" (EzToml.key2str key)
  in
  EzToml.encoding ~to_toml ~of_toml

let dependency_encoding =
  EzToml.encoding
    ~to_toml:(fun d ->
        let version = TString (string_of_versions d.depversions) in

        if { d with depversions = [] } =
           {
             depversions = [] ;
             depname = None ;
             deptest = false ;
             depdoc = false ;
             depopt = false } then
          version
        else
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
          let table =
            if d.depopt then
              EzToml.put [ "opt" ] (TBool true) table
            else
              table
          in
          TTable table)
    ~of_toml:(fun ~key v ->
        match v with
        | TString s ->
            let depversions = versions_of_string s in
            { depname = None; depversions;
              depdoc = false; deptest = false; depopt = false }
        | TTable table ->
            let depname = EzToml.get_string_option table [ "libname" ] in
            let depversions = EzToml.get_string_default table [ "version" ] "" in
            let depversions = versions_of_string depversions in
            let deptest = EzToml.get_bool_default table [ "for-test" ] false in
            let depdoc = EzToml.get_bool_default table [ "for-doc" ] false in
            let depopt = EzToml.get_bool_default table [ "opt" ] false in
            { depname; depversions; depdoc; deptest ; depopt }
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

let stringSet_encoding =
  EzToml.encoding
    ~to_toml:(fun set ->
        TArray (NodeString (StringSet.to_list set)))
    ~of_toml:(fun ~key v ->
        match v with
        | TArray NodeEmpty -> StringSet.empty
        | TArray (NodeString list) -> StringSet.of_list list
        | _ ->
            EzToml.expecting_type "string list" key
      )

let fields_encoding = EzToml.ENCODING.stringMap EzToml.string_encoding

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
                  with Not_found -> Error.raise "Cannot determine user name. Hint: try to set DROM_USER." ) ) ) ) ) )
    in
    let email =
      try Sys.getenv "DROM_EMAIL"
      with Not_found -> (
        try Sys.getenv "GIT_AUTHOR_EMAIL"
        with Not_found -> (
          try Sys.getenv "GIT_COMMITTER_EMAIL"
          with Not_found -> (
            try Git.email ()
            with Not_found -> Error.raise "Cannot determine user email. Hint: try to set DROM_EMAIL." ) ) )
    in
    Printf.sprintf "%s <%s>" user email

let string_of_package pk =
  EzToml.CONST.(s_ [
      option "name" ~comment:[ "name of package" ] ( string pk.name );
      option "skeleton" ( string_option pk.p_skeleton );

      option "version"
        ~comment:["version if different from project version"]
        ~default: {|version = "0.1.0"|}
        ( string_option pk.p_version );
      option "synopsis"
        ~comment: [ "synopsis if different from project synopsis" ]
        ( string_option pk.p_synopsis );
      option "description"
        ~comment: [ "description if different from project description" ]
        ( string_option pk.p_description );
      option "kind"
        ~comment: [ {|kind is either "library", "program" or "virtual"|} ]
        ( encoding kind_encoding pk.kind );
      option "authors"
        ~comment: [ "authors if different from project authors" ]
        ~default: {|authors = [ "Me <me@metoo.org>" ]|}
        ( string_list_option  pk.p_authors );
      option "gen-version"
        ~comment:[ "name of a file to generate with the current version" ]
        ~default:{|gen-version = "version.ml"|}
        ( string_option pk.p_gen_version );
      option "generators"
        ~comment:
          [ {|supported file generators are "ocamllex", "ocamlyacc" and "menhir" |};
            {| default is [ "ocamllex", "ocamlyacc" ] |}
          ]
        ~default: {|generators = [ "ocamllex", "menhir" ]|}
        ( encoding_option stringSet_encoding pk.p_generators );
      option "pack-modules"
        ~comment:
          [ "whether all modules should be packed/wrapped (default is true)" ]
        ~default: {|pack-modules = false|}
        ( bool_option pk.p_pack_modules );
      option "optional"
        ~comment:
          [ "whether the package can be silently skipped if missing deps (default is false)" ]
        ~default: {|optional = true|}
        ( bool_option pk.p_optional );
      option "pack"
        ~comment:
          [ "module name used to pack modules (if pack-modules is true)" ]
        ~default: {|pack = "Mylib"|}
        ( string_option pk.p_pack );
      option "preprocess"
        ~comment:
          [ "preprocessing options";
            {|  preprocess = "per-module (((action (run ./toto.sh %{input-file})) mod))" |}
          ]
        ~default: {|preprocess = "pps ppx_deriving_encoding"|}
        ( string_option pk.p_preprocess );

      option "skip"
        ~comment: [ "files to skip while updating at package level" ]
        ~default: {|skip = []|}
        ( string_list_option  pk.p_skip );

      option "dependencies"
        ~comment:[ "package library dependencies";
                   "   [dependencies]";
                   {|   ez_file = ">=0.1 <1.3"|};
                   {|   base-unix = { libname = "unix", version = ">=base" } |};
                 ]
         ( encoding dependencies_encoding pk.p_dependencies );
      option "tools"
        ~comment: [ "package tools dependencies" ]
        ( encoding dependencies_encoding pk.p_tools );
      option  "fields"
        ~comment:[
          "package fields (depends on package skeleton)";
          "Examples:";
          {|  dune-stanzas = "(preprocess (pps ppx_deriving_encoding))" |};
          {|  dune-libraries = "bigstring" |};
          {|  dune-trailer = "(install (..))" |};
          {|  opam-trailer = "pin-depends: [..]" |};
          {|  no-opam-test = "yes" |};
          {|  no-opam-doc = "yes" |};
          {|  gen-opam = "some" | "all" |};
        ]
        ( encoding fields_encoding pk.p_fields );
    ])

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

let package_of_toml ?default ?p_file table =
  let dir = EzToml.get_string_option table [ "dir" ] in
  let name = try EzToml.get_string table [ "name" ] with Not_found ->
    ( match dir with
      | Some dir_path ->
        let package_path = dir_path // "package.toml" in
        if Sys.file_exists package_path
        then Printf.eprintf "Error: Missing field 'name' in %s\n%!" package_path
        else Printf.eprintf "Error: %s is missing \n%!" package_path
      | None -> Printf.eprintf "Error: Missing field 'name' for a package in drom.toml\n%!" );
    exit 2
  in
  let default = find_package ?default name in
  let dir = Misc.option_value dir ~default:default.dir in
  let kind =
    EzToml.get_encoding_default kind_encoding table [ "kind" ] default.kind
  in
  let project = dummy_project in
  let p_pack =
    EzToml.get_string_option table [ "pack" ] ?default:default.p_pack
  in
  let p_preprocess =
    EzToml.get_string_option table [ "preprocess" ] ?default:default.p_pack
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
  let p_optional =
    EzToml.get_bool_option table [ "optional" ]
      ?default:default.p_optional
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
    EzToml.get_encoding_option stringSet_encoding table [ "generators" ]
      ?default:default.p_generators
  in
  let p_fields =
    EzToml.get_encoding_default fields_encoding table [ "fields" ]
      StringMap.empty
  in
  let p_fields =
    StringMap.union (fun _k a1 _a2 ->
        Some a1) p_fields default.p_fields
  in
  if verbose_subst then
    StringMap.iter (fun k _ ->
        Printf.eprintf "Package defined field %S\n%!" k;
      ) p_fields;
  let p_skip =
    EzToml.get_encoding_option skip_encoding table [ "skip" ]
      ?default:default.p_skip
  in

  { name;
    dir;
    project;
    p_pack;
    p_preprocess;
    p_file;
    kind;
    p_version;
    p_authors;
    p_synopsis;
    p_description;
    p_dependencies;
    p_tools;
    p_pack_modules;
    p_gen_version;
    p_fields;
    p_skeleton;
    p_generators;
    p_skip;
    p_optional;
  }

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
            Toml.Types.Table.union (fun _key _ v -> Some v
                (*
                Error.raise "File %s: key %s already exist in drom.toml"
                  filename (Toml.Types.Table.Key.to_string key)
*)
              ) package_table table
          in
          (table, Some filename)
        else
          (table, None)
  in
  package_of_toml ?default ?p_file table

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
  let dependencies =
    "# project-wide library dependencies (not for package-specific deps)\n" ^
    dependencies
  in
  let tools =
    match p.tools with
    | [] -> "[tools]\n"
    | _ ->
      EzToml.empty
      |> EzToml.put_encoding dependencies_encoding [ "tools" ] p.tools
      |> EzToml.to_string
  in
  let tools =
    "# project-wide tools dependencies (not for package-specific deps)\n" ^
    tools
  in
  let package3 =
    EzToml.CONST.(
      s_ ~section:"project"
        [
          option "skip-dirs"
            ~comment: [ "dirs to skip while scanning for dune files" ]
             (string_list p.skip_dirs) ;
          option "share-dirs"
            ~comment: [ "dirs to scan for share/ folders (with package names)" ]
            ( string_list p.share_dirs) ;
          option  "build-profile"
            ~comment: [ "build profile to use by default" ]
            ( string_option p.profile ) ;
          option  "profile"
            ~comment: [
              "Profile options for this project";
              {|    [profile]|};
              {|    dev = { ocaml-flags = "-w +a-4-40-41-42-44" }|};
              {|    release = { ocaml-flags = "-w -a" }|};
            ]
            (encoding
               (EzToml.ENCODING.stringMap profile_encoding) p.profiles);
          option  "fields"
            ~comment:[ "project-wide fields (depends on project skeleton)" ]
            ( encoding fields_encoding p.fields );
        ])
  in

  let files = ref [] in
  let packages =
    List.map
      (fun package ->
        let toml = string_of_package package in
        files :=
          (package.dir // "package.toml", toml) :: !files;
        package.dir, EzToml.empty |> EzToml.put_string [ "dir" ] package.dir)
      p.packages
  in
  let packages =
    String.concat "\n"
      (List.map (fun (dir, package) ->
           let s = EzToml.empty
                   |> EzToml.put [ "package" ] (TArray (NodeTable [package]))
                   |> EzToml.to_string
           in
           Printf.sprintf "%s# edit '%s' for package-specific options\n"
             s ( dir // "package.toml" )
         ) packages)
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

  let project_key = "project" in
  let project_packages =
    match EzToml.get table [ "package" ] with
    | exception _ -> []
    | TTable _ -> []
    | TArray (NodeTable tables) ->
        List.map (package_of_toml ?default) tables
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
      EzToml.get_encoding_option skip_encoding table [ "project"; "skip" ]
    with
    | Some list -> list
    | None ->
        match
          EzToml.get_string_option table [ "drom"; "skip" ]
            ~default:(String.concat " " d.skip)
        with
        | None -> []
        | Some s -> EzString.split s ' '
  in
  let _pack_modules = (* obsolete *)
    match EzToml.get_bool_option table [ project_key; "pack-modules" ] with
    | Some v -> v
    | None -> (
        match
          EzToml.get_bool_option table [ project_key; "wrapped" ]
            ~default:true
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

  let _generators = (* obsolete *)
    EzToml.get_string_list_default table
      [ project_key; "generators" ]
      []
  in
  let ci_systems = EzToml.get_string_list_default table
      [ project_key; "ci-systems" ]
      (
        let windows_ci =
          EzToml.get_bool_default table [ project_key; "windows-ci" ] true
        in
        if windows_ci then
          Misc.default_ci_systems
        else
          List.filter (fun s -> s <> "windows-latest") Misc.default_ci_systems
      )
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
              depdoc = false;
              depopt = false;
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
    EzToml.get_encoding_default fields_encoding table [ project_key; "fields" ]
      StringMap.empty
  in
  let p_fields =
    EzToml.get_encoding_default fields_encoding table [ "fields" ]
      StringMap.empty
  in
  let fields = StringMap.union (fun _k a1 _a2 ->  Some a1) fields d.fields in
  let fields = StringMap.union (fun _k a1 _a2 -> Some a1) fields p_fields in
  if verbose_subst then
    StringMap.iter (fun k _ ->
        Printf.eprintf "Project defined field %S\n%!" k;
      ) fields;

  let generators = ref StringSet.empty in
  List.iter (fun p ->
      match p.p_generators with
      | None -> ()
      | Some p_generators ->
          generators := StringSet.union !generators p_generators
    ) packages;
  let generators = !generators in
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
  let dune_version =
    let find = List.mem_assoc "dune" in
    (* No dune dependencies in packages tools or dependencies. *)
    List.iter (fun (p : package) ->
      if find p.p_dependencies then
        (* dune is in [p] dependencies which is silly: dune is a tool, not
           a library. *)
        Error.raise "Package %s has a dune dependency which has no meaning. Please remove it"
          p.name;
      if find p.p_tools then
        (* dune is in [p] tools which is bad project engineering design. *)
        Error.raise "Package %s gives dune as a tool dependency. Such dependency should appears at project level, please move it in drom.toml."
          p.name) packages;
    (* Legacy dune lang version specification *)
    let legacy_dune_lang = StringMap.find_opt "dune" p_fields in
    (* Checking that dune is not in project's dependencies, which has no more
       meaning than in packages *)
    if find dependencies then
      Error.raise "Project has a dune dependency which has no meaning. Please remove it or move it in [tools].";
    (* The valid way of overriding dune version. *)
    let dune_tool_spec = List.assoc_opt "dune" dependencies in
    (* Normalizing *)
    let versions = match legacy_dune_lang, dune_tool_spec with
      | None, None -> [Ge Globals.current_dune_version]
      | Some legacy, None -> [Ge legacy]
      | None, Some dep -> dep.depversions
      | Some legacy, Some dep -> Ge legacy :: dep.depversions in
    (* The only interesting version is the infimum of possible versions
       for we need to know if we can use some dune feature or not. We
       assume that dune is backward compatible. If it's not, we must
       track all needed feature dependencies on dune version which is
       a bit overkill for now. To compute the infimum, we use the
       bottom "2.0" version which is the initial dune version used
       in drom so no support can be expected on lower versions. *)
    match
      Misc.infimum
        ~default:Globals.current_dune_version
        ~current:version
        ~bottom:"2.0"
        versions
    with
    | `unknown ->
      Error.raise
        "Can't determine the dune minimal version. Please consider less restrictive dune specification."
    | `conflict (version, constraint_) ->
      Error.raise
        "dune version must be (>=%s), which contradicts the (%s) specification"
        version constraint_
    | `found version ->
      version in





  let project =
    { package;
      packages;
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
      share_dirs ;
      profile;
      fields;
      generators;
      year;
      dune_version;
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

let lookup () =
  Globals.find_ancestor_file Globals.drom_file
    (fun ~dir ~path -> (dir,path))

let find ?(display=true) () =
  match lookup () with
    None -> None
  | Some (dir, path) ->
      Unix.chdir dir;
      if display && Misc.verbose 1 then
        Printf.eprintf "drom: Entering directory '%s'\n%!" (Sys.getcwd ());
      Some ( project_of_filename Globals.drom_file, path )

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
