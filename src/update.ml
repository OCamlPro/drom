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

let template_DOTgitignore p =
  Printf.sprintf {|
/%s
*~
_build
.merlin
/_drom
/_opam
/_build
|} p.package.name

let library_name p =
  let s = Bytes.of_string p.name in
  for i = 1 to String.length p.name - 2 do
    let c = p.name.[i] in
    match c with
    | 'a'..'z' | '0'..'9' -> ()
    | _ -> Bytes.set s i '_'
  done;
  Bytes.to_string s

let library_module p =
  let s = Bytes.of_string p.name in
  Bytes.set s 0 ( Char.uppercase p.name.[0] );
  for i = 1 to String.length p.name - 2 do
    let c = p.name.[i] in
    match c with
    | 'a'..'z' | '0'..'9' -> ()
    | _ -> Bytes.set s i '_'
  done;
  Bytes.to_string s

let template_main_main_ml p =
  Printf.sprintf {|let () = %s.Main.main ()
|} ( library_module p )

let template_src_main_ml p =
  match p.kind with
  | Both ->
    Printf.sprintf
      {|
(* If you delete or rename this file, you should add '%s/main.ml' to the 'skip' field in "drom.toml" *)

let main () = Printf.printf "Hello world!\n%!"
|} p.package.dir
  | Program ->
    Printf.sprintf
      {|
(* If you rename this file, you should add '%s/main.ml' to the 'skip' field in "drom.toml" *)

let () = Printf.printf "Hello world!\n%!"
|}
      p.package.dir
  | Library -> assert false

let template_readme_md p =
  match p.github_organization with
  | None ->
    Printf.sprintf "# %s\n" p.package.name
  | Some github_organization ->
  Printf.sprintf {|
[![Actions Status](https://github.com/%s/%s/workflows/Main%%20Workflow/badge.svg)](https://github.com/%s/%s/actions)
[![Release](https://img.shields.io/github/release/%s/%s.svg)](https://github.com/%s/%s/releases)

# %s

%s

* Website: https://%s.github.io/%s
* General Documentation: https://%s.github.io/%s/sphinx
* API Documentation: https://%s.github.io/%s/doc
* Sources: https://github.com/%s/%s
|}
github_organization p.package.name
github_organization p.package.name
github_organization p.package.name
github_organization p.package.name
p.package.name
p.description
github_organization p.package.name
github_organization p.package.name
github_organization p.package.name
github_organization p.package.name

let template_src_dune package =
  let b = Buffer.create 1000 in
  let dependencies = List.map (fun (name, d) ->
      match d.depname with
      | None -> name
      | Some name -> name)  (Misc.p_dependencies package) in
  let p_mode = Misc.p_mode package in
  let dependencies =
    match p_mode with
    | Binary -> dependencies
    | Javascript ->
      if List.mem "js_of_ocaml" dependencies then
        dependencies
      else
        "js_of_ocaml" :: dependencies
  in
  let libraries = String.concat " " dependencies in

  begin
    match Misc.p_kind package with
    | Program ->
      Printf.bprintf b {|
(executable
 (name main)
 (public_name %s)
 (libraries %s)%s
)
|}
        package.name
        libraries
        (match p_mode with
         | Binary -> ""
         | Javascript ->
           {|
 (mode js)
 (preprocess (pps js_of_ocaml-ppx))|}
        )

    | Library ->
      Printf.bprintf b {|
(library
 (name %s)
 (public_name %s)%s
 (libraries %s)%s
)
|}
        ( library_name package)
        package.name
        (if not ( Misc.p_wrapped package ) then {|
 (wrapped false)|}
         else "")
        libraries
        (match p_mode with
         | Binary -> ""
         | Javascript ->
           {|
 (preprocess (pps js_of_ocaml-ppx))|}
        )

    | Both ->
      Printf.bprintf b {|
(library
 (name %s)
 (public_name %s_lib)
 (libraries %s)%s
)
|}
        ( library_name package )
        package.name libraries
        (match p_mode with
         | Binary -> ""
         | Javascript ->
           {|
 (preprocess (pps js_of_ocaml-ppx))|}
        )
  end;

  begin
    match Sys.readdir package.dir with
    | exception _ -> ()
    | files -> Array.iter (fun file ->
        let file = String.lowercase file in
        if Filename.check_suffix file ".mll" then
          Printf.bprintf b "(ocamllex %s)\n"
            ( Filename.chop_suffix file ".mll")
        else
        if Filename.check_suffix file ".mly" then
          Printf.bprintf b "(ocamlyacc %s)\n"
            ( Filename.chop_suffix file ".mly")
      ) files;
  end ;
  Buffer.contents b

let template_main_dune p =
  Printf.sprintf
    {|
(executable
 (name main)
 (public_name %s)
 (package %s)
 (libraries %s_lib)
)
|}
    p.name p.name p.name


let template_Makefile p =
  Printf.sprintf
  {|
.PHONY: all build-deps doc sphinx odoc view fmt fmt-check install dev-deps test
DEV_DEPS := merlin ocamlformat odoc

all: build

build:
	dune build%s

build-deps:
	opam install --deps-only ./%s.opam

sphinx:
	sphinx-build sphinx docs/sphinx

doc:
	dune build @doc
	rsync -auv --delete _build/default/_doc/_html/. docs/doc

view:
	xdg-open file://$$(pwd)/docs/index.html

fmt:
	dune build @fmt --auto-promote

fmt-check:
	dune build @fmt

install:
	dune install

uninstall:
	dune uninstall

dev-deps:
	opam install -y ${DEV_DEPS}

test:
	dune build @runtest
|}
  (match Misc.p_kind p.package with
   | Library -> ""
   | Program ->
     Printf.sprintf {|
	cp -f _build/default/%s/main.exe %s
|} p.package.dir p.package.name
   | Both ->
     Printf.sprintf {|
	cp -f _build/default/main/main.exe %s
|} p.package.name
  )
  p.package.name

let template_DOTgithub_workflows_ci_ml _p =
  {|
(* Credits: https://github.com/ocaml/dune *)
open StdLabels

let skip_test =
  match Sys.getenv "SKIP_TEST" with
  | exception Not_found -> false
  | s -> bool_of_string s

let run cmd args =
  (* broken when arguments contain spaces but it's good enough for now. *)
  let cmd = String.concat " " (cmd :: args) in
  match Sys.command cmd with
  | 0 -> ()
  | n ->
    Printf.eprintf "'%s' failed with code %d" cmd n;
    exit n

let opam args = run "opam" args

let pin () =
  let packages =
    let packages = Sys.readdir "." |> Array.to_list in
    let packages =
      List.fold_left packages ~init:[] ~f:(fun acc fname ->
          if Filename.check_suffix fname ".opam" then
            Filename.chop_suffix fname ".opam" :: acc
          else
            acc)
    in
    if skip_test then
      List.filter packages ~f:(fun pkg -> pkg = "dune")
    else
      packages
  in
  List.iter packages ~f:(fun package ->
      opam [ "pin"; "add"; package ^ ".next"; "."; "--no-action" ])

let test () =
    opam [ "install"; "."; "--deps-only"; "--with-test" ];
    run "make" [ "dev-deps" ];
    run "make" [ "test" ]

let () =
  match Sys.argv with
  | [| _; "pin" |] -> pin ()
  | [| _; "test" |] -> test ()
  | _ ->
    prerr_endline "Usage: ci.ml [pin | test]";
    exit 1
|}

let template_DOTgithub_workflows_workflow_yml p =
  Printf.sprintf
    {|
name: Main Workflow

on:
  - push
  - pull_request

jobs:
  build:
    strategy:
      fail-fast: false
      matrix:
        os:
          - macos-latest
          - ubuntu-latest
          - windows-latest
        ocaml-version:
          - %s
        skip_test:
          - false
%s
    env:
      SKIP_TEST: ${{ matrix.skip_test }}
      OCAML_VERSION: ${{ matrix.ocaml-version }}
      OS: ${{ matrix.os }}

    runs-on: ${{ matrix.os }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v2

      - name: Use OCaml ${{ matrix.ocaml-version }}
        uses: avsm/setup-ocaml@v1
        with:
          ocaml-version: ${{ matrix.ocaml-version }}

      - name: Set git user
        run: |
          git config --global user.name github-actions
          git config --global user.email github-actions-bot@users.noreply.github.com

      - run: opam exec -- ocaml .github/workflows/ci.ml pin

      - run: opam install ./%s.opam --deps-only --with-test

      - run: opam exec -- make all

      - name: run test suite
        run: opam exec -- ocaml .github/workflows/ci.ml test
        if: env.SKIP_TEST != 'true'

      - name: test source is well formatted
        run: opam exec -- make fmt-check
        continue-on-error: true
        if: env.OCAML_VERSION == '%s' && env.OS == 'ubuntu-latest'
|}
    p.edition
    (if p.edition = p.min_edition then "" else
       Printf.sprintf
       {|
        include:
          - ocaml-version: %s
            os: ubuntu-latest
            skip_test: true
|} p.min_edition)
    ( match p.kind with
      | Both -> p.package.name ^ "_lib"
      | Library | Program -> p.package.name)
    p.edition

let template_CHANGES_md _p =
  let tm = Misc.date () in
  Printf.sprintf {|
## v0.1.0 ( %04d-%02d-%02d )

* Initial commit
|}
    tm.Unix.tm_year
    tm.Unix.tm_mon
    tm.Unix.tm_mday



let semantic_version version =
  match EzString.split version '.' with
    [ major ; minor ; fix ] ->
    begin try
        Some ( int_of_string major, int_of_string minor, int_of_string fix )
      with
        Not_found -> None
    end
  | _ -> None

let bug_reports p =
  match p.bug_reports with
  | Some s -> Some s
  | None ->
    match p.github_organization with
    | Some organization ->
      Some ( Printf.sprintf "https://github.com/%s/%s/issues"
               organization p.package.name )
    | None -> None

let dev_repo p =
  match p.dev_repo with
  | Some s -> Some s
  | None ->
    match p.github_organization with
    | Some organization ->
      Some ( Printf.sprintf "git+https://github.com/%s/%s.git"
               organization p.package.name )
    | None -> None

let template_docs_index_html p =
  Printf.sprintf {|
<h1>%s</h1>

<p>%s</p>

<ul>%s%s%s%s
</ul>
|}
    p.package.name
    p.description
    ( match p.github_organization with
      | None -> ""
      | Some github_organization ->
        let link = Printf.sprintf "https://github.com/%s/%s"
            github_organization p.package.name in
        Printf.sprintf {|
<li><a href="%s">Project on Github</a></li>|} link)
    ( match Misc.doc_gen p with
      | None -> ""
      | Some link ->
        Printf.sprintf {|
<li><a href="%s">General Documentation</a></li>|} link)
    ( match Misc.doc_api p with
      | None -> ""
      | Some link ->
        Printf.sprintf {|
<li><a href="%s">API Documentation</a></li>|} link)
    ( match bug_reports p with
      | None -> ""
      | Some link ->
        Printf.sprintf {|
<li><a href="%s">Bug reports</a></li>|} link)

type opam_kind =
  | Single
  | LibraryPart
  | ProgramPart

let opam_of_project kind package =
  let p = package.project in
  let open OpamParserTypes in
  let file_name = "opam" in
  let pos = file_name, 0,0 in
  let string s = String (pos, s) in
  let list v = List (pos, v) in
  let var_string s v = Variable (pos, s, string v) in
  let var_list s v = Variable (pos, s, list v) in
  let optionals = ref [] in
  let add_optional_string s = function
    | None -> ()
    | Some v -> optionals := ( var_string s v ) :: !optionals
  in
  add_optional_string "homepage" ( Misc.homepage p );
  add_optional_string "doc" ( Misc.doc_gen p );
  add_optional_string "bug-reports" ( bug_reports p );
  add_optional_string "dev-repo" (dev_repo p );

  let file_contents = [
    var_string "opam-version" "2.0";
    var_string "name" ( match kind with
        | LibraryPart -> package.name ^ "_lib"
        | Single | ProgramPart -> package.name ) ;
    var_string "version" ( Misc.p_version package ) ;
    var_string "license" ( License.name p ) ;
    var_string "synopsis" ( match kind with
        | LibraryPart -> Misc.p_synopsis package ^ " (library)"
        | Single | ProgramPart -> Misc.p_synopsis package );
    var_string "description" (Misc.p_description package ) ;
    var_list "authors" ( List.map string ( Misc.p_authors package ) ) ;
    var_list "maintainer" ( List.map string p.authors ) ;
  ] @ List.rev !optionals @
    [
      Variable (pos, "build",
                OpamParser.value_from_string
                  {|
[
  ["dune" "subst"] {pinned}
  ["dune" "build" "-p" name "-j" jobs "@install"
     "@runtest" {with-test}
    "@doc" {with-doc}
  ]
]
|} file_name);
      Variable (pos, "depends",
                match kind with
                | ProgramPart ->
                  List (pos,
                        [
                          OpamParser.value_from_string
                            ( Printf.sprintf {|
                                "%s_lib" { = version }
|} package.name ) file_name
                        ]
                       )
                | Single | LibraryPart ->
                  List (pos,
                        OpamParser.value_from_string
                          ( Printf.sprintf {| "ocaml" { >= "%s" } |}
                              p.min_edition
                          )
                          file_name
                        ::
                        List.map (fun (name, d) ->
                              OpamParser.value_from_string (
                                match semantic_version d.depversion with
                                | Some (major, minor, fix) ->
                                  Printf.sprintf
                                    {| "%s" { >= "%d.%d.%d" & < "%d.0.0" }|}
                                    name major minor fix (major+1)
                                | None ->
                                  Printf.sprintf
                                    {| "%s" {= "%s" } |} name d.depversion
                              )
                                file_name
                          )
                          ( Misc.p_dependencies package )
                        @
                        List.map (fun (name, version) ->
                            OpamParser.value_from_string (
                              match semantic_version version with
                              | Some (major, minor, fix) ->
                                Printf.sprintf
                                  {| "%s" { >= "%d.%d.%d" & < "%d.0.0" }|}
                                  name major minor fix (major+1)
                              | None ->
                                Printf.sprintf
                                  {| "%s" {= "%s" } |} name version
                            )
                              file_name
                          )
                          ( Misc.p_tools package ) )
               )
    ]
  in
  let f =
    {
      file_contents ;
      file_name
    }
  in
  let s = OpamPrinter.opamfile f in
  Printf.sprintf
    {|# This file was generated by `drom` from `drom.toml`.
Do not modify or add to the `skip` field of `drom.toml`.
%s|}
    s


let update_files ?kind ?mode ?(git=false) ?(create=false) p =

  let can_skip = ref [] in
  let not_skipped s =
    can_skip := s :: !can_skip;
    not ( List.mem s p.skip ) in
  let save_hashes = ref false in
  let hashes =
    if Sys.file_exists ".drom" then
      let map = ref StringMap.empty in
      Printf.eprintf "Loading .drom\n%!";
      Array.iter (fun line ->
          if line <> "" && line.[0] <> '#' then
            let ( digest, filename ) = EzString.cut_at line ' ' in
            let digest = Digest.from_hex digest in
            map := StringMap.add filename digest !map
        )
        ( EzFile.read_lines ".drom")  ;
      !map
    else StringMap.empty
  in
  let hashes = ref hashes in
  let to_add = ref [] in
  let to_remove = ref [] in
  let write_file filename content =
    let dirname = Filename.dirname filename in
    EzFile.make_dir ~p:true dirname ;
    EzFile.write_file filename content ;
    hashes := StringMap.add filename ( Digest.string content ) !hashes ;
    save_hashes := true ;
    to_add := filename :: !to_add ;
  in
  let can_update ~filename content =
    let old_content = EzFile.read_file filename in
    if content = old_content then begin
      false
    end else
      let hash = Digest.string old_content in
      try
        let former_hash = StringMap.find filename !hashes in
        let not_modified = former_hash = hash in
        if not not_modified then
          Printf.eprintf "Skipping modified file %s\n%!" filename ;
        not_modified
      with Not_found ->
        Printf.eprintf "Skipping existing file %s\n%!" filename ;
        false
  in
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
  let write_file filename content =
    if not_skipped filename then
      if not ( Sys.file_exists filename ) then begin
        Printf.eprintf "Creating file %s\n%!" filename;
        write_file filename content
      end else
      if can_update ~filename content then begin
        Printf.eprintf "Updating file %s\n%!" filename;
        write_file filename content
      end
  in

  let config = Lazy.force Config.config in

  let old_p = p in
  let p =
    match p.github_organization, config.config_github_organization with
    | None, Some s -> { p with github_organization = Some s }
    | _ -> p
  in
  let p =
    match p.authors, config.config_author with
    | [], Some s -> { p with authors = [ s ] }
    | _ -> p
  in
  let p =
    match p.copyright, config.config_copyright with
    | None, Some s -> { p with copyright = Some s }
    | _ -> p
  in
  let p = match kind with
    | None -> p
    | Some kind -> { p with kind }
  in
  let p = match mode with
    | None -> p
    | Some mode ->
      let js_dep = ( "js_of_ocaml", { depversion = "3.6" ; depname = None } ) in
      let js_tool = ( "js_of_ocaml", "3.6") in
      let ppx_tool = ( "js_of_ocaml-ppx", "3.6" ) in
      let add_dep dep deps = match mode with
        | Binary ->
          if List.mem dep deps then
            EzList.remove dep deps
          else
            deps
        | Javascript ->
          if not ( List.mem_assoc (fst dep) deps ) then
            dep :: deps
          else
            deps
      in
      let dependencies = add_dep js_dep p.dependencies in
      let tools = add_dep js_tool p.tools in
      let tools = add_dep ppx_tool tools in
      { p with mode ; dependencies ; tools }
  in

  if p <> old_p ||  not ( Sys.file_exists "drom.toml" ) then
    write_file "drom.toml" ( Project.toml_of_project p ) ;
  write_file ".gitignore" ( template_DOTgitignore p ) ;
  write_file "Makefile" ( template_Makefile p ) ;
  (*   write_file "dune-workspace" ""; *)
  write_file "README.md" ( template_readme_md p ) ;
  write_file ( p.package.dir // "dune" ) ( template_src_dune p.package ) ;
  if Misc.p_kind p.package = Both then begin
    write_file "main/dune" ( template_main_dune p.package ) ;
    write_file "main/main.ml" ( template_main_main_ml p.package ) ;
  end else begin
    remove_file "main/dune" ;
    remove_file "main/main.ml" ;
  end ;
  begin
    match Misc.p_kind p.package with
    | Library -> ()
    | Program | Both ->
      write_file ( p.package.dir // "main.ml" ) ( template_src_main_ml p ) ;
  end ;

  write_file "CHANGES.md" ( template_CHANGES_md p ) ;
  if create then begin
    if git && not ( Sys.file_exists ".git" ) then begin
      Misc.call [| "git"; "init" |];
      match config.config_github_organization with
      | None -> ()
      | Some organization ->
        Misc.call [| "git"; "remote" ; "add" ; "origin" ;
                     Printf.sprintf
                       "git@github.com:%s/%s"
                       organization
                       p.package.name |];
        Misc.call [| "git"; "add" ; "README.md" |];
        Misc.call [| "git"; "commit" ; "-m" ; "Initial commit" |];
    end
  end ;

  if not_skipped "docs" then begin

    write_file "docs/index.html"
      ( template_docs_index_html p ) ;

    if not ( Sys.file_exists  "docs/doc/index.html" ) then
      write_file "docs/doc/index.html"
        ( Printf.sprintf {|
<h1>API documentation for %s</h1>
<p>You need to run the following commands in the project to generate this doc:
<pre>
make doc
</pre>
or
<pre>
drom doc
</pre>
and then:
<pre>
git add docs/doc
</pre>
</p>
|} p.package.name ) ;

    if not ( Sys.file_exists "docs/sphinx/index.html" ) then
      write_file "docs/sphinx/index.html"
        ( Printf.sprintf {|
<h1>Sphinx doc for %s</h1>
<p>You need to run the following commands in the project to generate this doc:
<pre>
make sphinx
</pre>
or
<pre>
drom sphinx
</pre>
and then:
<pre>
git add docs/sphinx
</pre>
</p>
|} p.package.name ) ;
  end;

  if not_skipped "sphinx" then begin
    write_file "docs/.nojekyll" "";
    write_file "sphinx/conf.py" ( Sphinx.conf_py p ) ;
    write_file "sphinx/index.rst" ( Sphinx.index_rst p ) ;
    write_file "sphinx/install.rst" ( Sphinx.install_rst p ) ;
    write_file "sphinx/license.rst" ( Sphinx.license_rst p ) ;
    write_file "sphinx/about.rst" ( Sphinx.about_rst p ) ;
    write_file "sphinx/_static/css/fixes.css" "";
  end;

  let dune_project =
    let b = Buffer.create 100000 in
    Printf.bprintf b
      {|(lang dune 2.0)
; This file was generated by drom, using drom.toml
(name %s)
(allow_approximate_merlin)
(generate_opam_files false)
(version %s)
|}
      p.package.name
      p.version ;

    Printf.bprintf b {|
(package
 (name %s)
 (synopsis %S)
 (description %S)
|}
      ( if p.kind = Both then p.package.name ^ "_lib" else p.package.name )
      ( if p.kind = Both then
          ( Misc.p_synopsis p.package ) ^ " (library)" else
          Misc.p_synopsis p.package )
      p.description ;
    Printf.bprintf b " (depends\n";
    Printf.bprintf b "   (ocaml (>= %s))\n" p.min_edition ;
    List.iter (fun (name, d) ->
        match semantic_version d.depversion with
        | Some (major, minor, fix) ->
          Printf.bprintf b "   (%s (and (>= %d.%d.%d) (< %d.0.0)))\n"
            name major minor fix (major+1)
        | None ->
          Printf.bprintf b "   (%s (= %s))\n" name d.depversion
      ) ( Misc.p_dependencies p.package ) ;
    List.iter (fun (name, version) ->
        match semantic_version version with
        | Some (major, minor, fix) ->
          Printf.bprintf b "   (%s (and (>= %d.%d.%d) (< %d.0.0)))\n"
            name major minor fix (major+1)
        | None ->
          Printf.bprintf b "   (%s (= %s))\n" name version
      ) ( Misc.p_tools p.package ) ;
    Printf.bprintf b " )\n";
    Printf.bprintf b ")\n";

    if p.kind = Both then begin
      Printf.bprintf b {|
(package
 (name %s)
 (synopsis "%s")
 (description "%s")
 (depends (%s_lib (= %s)))
 )
|}
        p.package.name
        ( Misc.p_synopsis p.package )
        ( Misc.p_description p.package )
        p.package.name
        ( Misc.p_version p.package )
    end ;

    Buffer.contents b
  in
  write_file "dune-project" dune_project ;
  write_file ".ocamlformat" "" ;

  if not_skipped "workflows" then begin

    let workflows_dir = ".github/workflows" in

    write_file ( workflows_dir // "ci.ml" )
      ( template_DOTgithub_workflows_ci_ml p ) ;
    write_file ( workflows_dir // "workflow.yml" )
      ( template_DOTgithub_workflows_workflow_yml p ) ;

  end;

  let opam_filename, kind =
    match p.kind with
    | Both ->
      ( p.package.name ^ "_lib.opam", LibraryPart )
    | Library | Program ->
      ( p.package.name ^ ".opam", Single )
  in
  write_file opam_filename ( opam_of_project kind p.package ) ;
  begin
    match p.kind with
    | Library | Program ->
      remove_file ( p.package.name ^ "_lib.opam" )
    | Both ->
      write_file ( p.package.name ^ ".opam" )
        ( opam_of_project ProgramPart p.package )
  end;

  EzFile.make_dir ~p:true Globals.drom_dir ;
  EzFile.write_file ( Globals.drom_dir // "known-licences.txt" )
    ( License.known_licenses () );

  if not_skipped "license" then
    write_file "LICENSE.md" ( License.license p ) ;

  EzFile.write_file ( Globals.drom_dir // "maximum-skip-field.txt" )
    ( Printf.sprintf "skip = \"%s\"\n"
        ( String.concat " " !can_skip )) ;

  if !save_hashes then
    let b = Buffer.create 1000 in
    Printf.bprintf b
      "# Keep this file in your GIT repo to help drom track generated files\n";
    StringMap.iter (fun filename hash ->
        Printf.bprintf b "%s %s\n"
          ( Digest.to_hex hash ) filename ) !hashes ;
    EzFile.write_file ".drom" ( Buffer.contents b ) ;
    if git then begin
      Misc.call
        ( Array.of_list
            ( "git" :: "add" :: ".drom" :: !to_add ));
      match !to_remove with
      | [] -> ()
      | files ->
        Misc.call
          ( Array.of_list
              ( "git" :: "rm" :: files ))
    end
