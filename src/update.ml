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
|} p.name

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
  | Library | Both ->
    {|
(* If you rename this file, you should add 'main.ml' to the 'skip' field in "drom.toml" *)

let main () = Printf.printf "Hello world!\n%!"
|}
  | Program ->
    {|
(* If you rename this file, you should add 'main.ml' to the 'skip' field in "drom.toml" *)

let () = Printf.printf "Hello world!\n%!"
|}

let template_readme_md p =
  match p.github_organization with
  | None ->
    Printf.sprintf "# %s\n" p.name
  | Some github_organization ->
  Printf.sprintf {|
[![Actions Status](https://github.com/%s/%s/workflows/Main%%20Workflow/badge.svg)](https://github.com/%s/%s/actions)
[![Release](https://img.shields.io/github/release/%s/%s.svg)](https://github.com/%s/%s/releases)

# %s

%s

* Website: https://%s.github.io/%s
* Documentation: https://%s.github.io/%s/doc
|}
github_organization p.name
github_organization p.name
github_organization p.name
github_organization p.name
p.name
p.description
github_organization p.name
github_organization p.name

let template_src_dune p =
  let libraries = String.concat " " ( List.map fst p.dependencies ) in
  match p.kind with
  | Program ->
    Printf.sprintf {|
(executable
 (name main)
 (public_name %s)
 (libraries %s)
)
|} p.name libraries

  | Library ->
    Printf.sprintf {|
(library
 (name main)
 (public_name %s)
 (libraries %s)
)
|} p.name libraries

  | Both ->
    Printf.sprintf {|
(library
 (name %s)
 (public_name %s-lib)
 (libraries %s)
)
|}
      ( library_name p )
      p.name libraries

let template_main_dune p =
  Printf.sprintf
    {|
(executable
 (name main)
 (public_name %s)
 (package %s)
 (libraries %s-lib)
)
|}
    p.name p.name p.name


let template_Makefile p =
  Printf.sprintf
  {|
DEV_DEPS := merlin ocamlformat

all:
	dune build%s

build-deps:
	opam install --deps-only ./%s.opam

doc: html

html:
	sphinx-build sphinx docs/doc

view:
	xdg-open file://$$(pwd)/docs/doc/index.html

fmt:
	dune build @fmt --auto-promote

fmt-check:
	dune build @fmt

install:
	dune install

dev-deps:
	opam install -y ${DEV_DEPS}

test:
	dune build @runtest
|}
  (match p.kind with
   | Library -> ""
   | Program ->
     Printf.sprintf {|
	cp -f _build/default/src/main.exe %s
|} p.name
   | Both ->
     Printf.sprintf {|
	cp -f _build/default/main/main.exe %s
|} p.name
  )
  p.name

let template_DOTgithub_workflows_ci_ml _p =
  {|
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
  if Sys.win32 then (
    opam [ "install"; "./dune-configurator.opam"; "--deps-only" ];
    run "make" [ "test-windows" ]
  ) else (
    opam [ "install"; "."; "--deps-only"; "--with-test" ];
    run "make" [ "dev-deps" ];
    run "make" [ "test" ]
  )

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

#      - name: test source is well formatted
#        run: opam exec -- make fmt-check
#        if: env.OCAML_VERSION == '%s' && env.OS == 'ubuntu-latest'
|}
    p.edition
    ( match p.kind with
      | Both -> p.name ^ "-lib"
      | Library | Program -> p.name)
    p.edition

let semantic_version version =
  match EzString.split version '.' with
    [ major ; minor ; fix ] ->
    begin try
        Some ( int_of_string major, int_of_string minor, int_of_string fix )
      with
        Not_found -> None
    end
  | _ -> None

let homepage p =
  match p.homepage with
  | Some s -> Some s
  | None ->
    match p.github_organization with
    | Some organization ->
      Some ( Printf.sprintf "https://%s.github.com/%s" organization p.name )
    | None -> None

let documentation p =
  match p.documentation with
  | Some s -> Some s
  | None ->
    match p.github_organization with
    | Some organization ->
      Some ( Printf.sprintf "https://%s.github.com/%s" organization p.name )
    | None -> None

let bug_reports p =
  match p.bug_reports with
  | Some s -> Some s
  | None ->
    match p.github_organization with
    | Some organization ->
      Some ( Printf.sprintf "https://github.com/%s/%s/issues"
               organization p.name )
    | None -> None

let dev_repo p =
  match p.dev_repo with
  | Some s -> Some s
  | None ->
    match p.github_organization with
    | Some organization ->
      Some ( Printf.sprintf "git+https://github.com/%s/%s.git"
               organization p.name )
    | None -> None

let template_docs_index_html p =
  Printf.sprintf {|
<h1>%s</h1>

<p>%s</p>

<ul>%s%s
</ul>
|}
    p.name
    p.description
    ( match documentation p with
      | None -> ""
      | Some link ->
        Printf.sprintf {|
<li><a href="%s">Documentation</a></li>|} link)
    ( match bug_reports p with
      | None -> ""
      | Some link ->
        Printf.sprintf {|
<li><a href="%s">Bug reports</a></li>|} link)

type opam_kind =
  | Single
  | LibraryPart
  | ProgramPart

let opam_of_project kind p =
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
  add_optional_string "homepage" ( homepage p );
  add_optional_string "doc" ( documentation p );
  add_optional_string "license" p.license ;
  add_optional_string "bug-reports" ( bug_reports p );
  add_optional_string "dev-repo" (dev_repo p );

  let file_contents = [
    var_string "opam-version" "2.0";
    var_string "name" ( match kind with
        | LibraryPart -> p.name ^ "-lib"
        | Single | ProgramPart -> p.name ) ;
    var_string "version" p.version ;
    var_string "synopsis" ( match kind with
        | LibraryPart -> p.synopsis ^ " (library)"
        | Single | ProgramPart -> p.synopsis );
    var_string "description" p.description ;
    var_list "authors" ( List.map string p.authors ) ;
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
                                "%s-lib" { = "%s" }
|} p.name p.version ) file_name
                        ]
                       )
                | Single | LibraryPart ->
                  List (pos,
                        OpamParser.value_from_string
                          ( Printf.sprintf {| "ocaml" { >= "%s" } |}
                              p.edition
                          )
                          file_name
                        ::
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
                          ( p.dependencies @ p.tools )
                       ))
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
    "# This file was generated by `drom` from `drom.toml`. Do not modify.\n%s"
    s

let update_files ~create ~build p =

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
    if content = old_content then
      false
    else
      let hash = Digest.string old_content in
      try
        let former_hash = StringMap.find filename !hashes in
        let not_modified = former_hash = hash in
        if not not_modified then
          Printf.eprintf "Skipping modified file %s\n%!" filename ;
        not_modified
      with Not_found -> false
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
    if not ( List.mem filename p.ignore ) then
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

  let p =
    match p.license, config.config_license with
    | None, Some s -> { p with license = Some s }
    | _ -> p
  in
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
  write_file "drom.toml" ( Project.toml_of_project p ) ;
  write_file ".gitignore" ( template_DOTgitignore p ) ;
  write_file "Makefile" ( template_Makefile p ) ;
  write_file "dune-workspace" "";
  write_file "README.md" ( template_readme_md p ) ;
  write_file "src/dune" ( template_src_dune p ) ;
  if p.kind = Both then begin
    write_file "main/dune" ( template_main_dune p ) ;
    write_file "main/main.ml" ( template_main_main_ml p ) ;
  end else begin
    remove_file "main/dune" ;
    remove_file "main/main.ml" ;
  end ;
  write_file "src/main.ml" ( template_src_main_ml p ) ;

  if create then begin
    if not ( Sys.file_exists ".git" ) then begin
      Misc.call [| "git"; "init" |];
      match config.config_github_organization with
      | None -> ()
      | Some organization ->
        Misc.call [| "git"; "remote" ; "add" ; "origin" ;
                     Printf.sprintf
                       "git@github.com:%s/%s"
                       organization
                       p.name |];
        Misc.call [| "git"; "add" ; "README.md" |];
        Misc.call [| "git"; "commit" ; "-m" ; "Initial commit" |];
    end
  end ;

  if not ( List.mem "docs" p.ignore ) then begin

    write_file "docs/index.html"
      ( template_docs_index_html p ) ;
    write_file "docs/doc/index.html"
      ( Printf.sprintf {|
<h1>Sphinx doc for %s</h1>
<p>You need to run the following commands in the project to generate the doc:
<pre>
make doc
git add docs/
git commit -m "Add generated documentation"
</pre>
</p>
|} p.name ) ;
  end;

  if not ( List.mem "sphinx" p.ignore ) then begin
    write_file "docs/.nojekyll" "";
    write_file "sphinx/conf.py" ( Sphinx.conf_py p ) ;
    write_file "sphinx/index.rst" ( Sphinx.index_rst p ) ;
    write_file "sphinx/usage.rst" ( Sphinx.usage_rst p ) ;
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
      p.name
      p.version ;

    Printf.bprintf b {|
(package
 (name %s)
 (synopsis %S)
 (description %S)
|}
      ( if p.kind = Both then p.name ^ "-lib" else p.name )
      ( if p.kind = Both then p.synopsis ^ " (library)" else p.synopsis )
      p.description ;
    Printf.bprintf b " (depends\n";
    Printf.bprintf b "   (ocaml (= %s))\n" p.edition ;
    List.iter (fun (name, version) ->
        match semantic_version version with
        | Some (major, minor, fix) ->
          Printf.bprintf b "   (%s (and (>= %d.%d.%d) (< %d.0.0)))\n"
            name major minor fix (major+1)
        | None ->
          Printf.bprintf b "   (%s (= %s))\n" name version
      ) ( p.dependencies @ p.tools );
    Printf.bprintf b " )\n";
    Printf.bprintf b ")\n";

    if p.kind = Both then begin
      Printf.bprintf b {|
(package
 (name %s)
 (synopsis "%s")
 (description "%s")
 (depends (%s-lib (= %s)))
 )
|}
        p.name
        p.synopsis
        p.description
        p.name p.version
    end ;

    Buffer.contents b
  in
  write_file "dune-project" dune_project ;
  write_file ".ocamlformat" "" ;

  if not ( List.mem "workflows" p.ignore ) then begin

    let workflows_dir = ".github/workflows" in

    write_file ( workflows_dir // "ci.ml" )
      ( template_DOTgithub_workflows_ci_ml p ) ;
    write_file ( workflows_dir // "workflow.yml" )
      ( template_DOTgithub_workflows_workflow_yml p ) ;

  end;

  let opam_filename, kind =
    match p.kind with
    | Both ->
      ( p.name ^ "-lib.opam", LibraryPart )
    | Library | Program ->
      ( p.name ^ ".opam", Single )
  in
  write_file opam_filename ( opam_of_project kind p ) ;
  begin
    match p.kind with
    | Library | Program ->
      remove_file ( p.name ^ "-lib.opam" )
    | Both ->
      write_file ( p.name ^ ".opam" )
        ( opam_of_project ProgramPart p )
  end;


  if build then
    begin
      let drom_opam_filename = "_drom/opam" in
      let former_opam_file =
        if Sys.file_exists drom_opam_filename then
          Some ( EzFile.read_file drom_opam_filename )
        else None
      in
      let new_opam_file = EzFile.read_file opam_filename in
      if former_opam_file <> Some new_opam_file ||
         not ( Sys.file_exists "_opam" ) then begin
        Printf.eprintf "Updating %s\n%!" drom_opam_filename ;

        let ocaml_nv = "ocaml." ^ p.edition in
        if Sys.file_exists "_opam" &&
           not ( Sys.file_exists ( "_opam" // ".opam-switch" // "packages"
                                   // ocaml_nv )) then begin
          error "Wrong ocaml version in _opam. Expecting %s. Remove '_opam/' or change the project edition" ocaml_nv
        end;

        if not ( Sys.file_exists "_opam" ) then begin
          Misc.call [| "opam" ; "switch" ; "create"; "." ; "--empty" |];
          let packages = [
            ocaml_nv ;
            "ocamlformat" ;
            "user-setup" ;
            "merlin" ;
            "odoc" ;
          ] in
          Misc.call ( Array.of_list
                        ( "opam" :: "install" :: "-y" :: packages ) );
        end ;

        let tmp_opam_filename = "_drom/new.opam" in
        EzFile.make_dir ~p:true "_drom";
        EzFile.write_file tmp_opam_filename new_opam_file ;

        Misc.call [| "opam" ; "install" ; "-y" ; "--deps-only";
                     "." // tmp_opam_filename |];

        begin try Sys.remove drom_opam_filename with _ -> () end ;
        Sys.rename tmp_opam_filename drom_opam_filename;

      end

    end;

  if !save_hashes then
    let b = Buffer.create 1000 in
    Printf.bprintf b
      "# Keep this file in your GIT repo to help drom track generated files\n";
    StringMap.iter (fun filename hash ->
        Printf.bprintf b "%s %s\n"
          ( Digest.to_hex hash ) filename ) !hashes ;
    EzFile.write_file ".drom" ( Buffer.contents b ) ;
    Misc.call
      ( Array.of_list
          ( "git" :: "add" :: ".drom" :: !to_add ));
    match !to_remove with
    | [] -> ()
    | files ->
      Misc.call
        ( Array.of_list
            ( "git" :: "rm" :: files ))
